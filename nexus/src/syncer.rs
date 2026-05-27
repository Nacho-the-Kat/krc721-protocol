use crate::analyzer::{Analyzer, ContextTransaction};
use crate::bridge::BridgeT;
use crate::consumer::ConsumerT;
use crate::imports::*;
use crate::metrics::Metrics;
use crate::state::State;
use ahash::AHashMap;
use kaspa_consensus_core::tx::ScriptPublicKey;
use kaspa_rpc_core::{
    GetVirtualChainFromBlockV2Response, RpcChainBlockAcceptedTransactions, RpcHash,
    RpcOptionalTransaction, VirtualChainChangedNotification,
};
use krc721_core::model::krc721::{
    BlueScoredChainBlockHash, Mergeset, MergesetOperation, VirtualChainChanges,
};
use tracing::{instrument, Instrument};

use krc721_core::model::krc721::Tick;
pub type ReservedTokenMap = AHashMap<Tick, ScriptPublicKey>;

const SYNC_ERROR_THRESHOLD_SECONDS: u64 = 15;

pub struct Syncer {
    // This will be used for performance / realtime metrics / counters
    // Counters that track collections, tokens, owners, etc
    // should live in a dedicated database.
    #[allow(unused)]
    metrics: Arc<Metrics>,
    bridge: Arc<dyn BridgeT>,
    is_synced: AtomicBool,

    processor: Arc<Processor>,
    last_known_block: Mutex<Option<BlueScoredChainBlockHash>>,
    target: Mutex<Option<BlueScoredChainBlockHash>>,
    last_error_timestamp: AtomicU64,

    shutting_down: AtomicBool,
    analyzer: Analyzer,
}

impl SyncerT for Syncer {
    fn is_synced(&self) -> bool {
        self.is_synced.load(std::sync::atomic::Ordering::SeqCst)
    }

    fn last_known_block(&self) -> Option<BlueScoredChainBlockHash> {
        *self.last_known_block.lock().unwrap()
    }

    fn spawn(self: Arc<Self>, last_known_block: RpcHash) {
        self.spawn_sync_task(last_known_block);
    }

    fn shutdown(&self) {
        self.shutting_down.store(true, Ordering::SeqCst);
    }
}

impl Syncer {
    pub fn new(
        _state: Arc<State>,
        metrics: Arc<Metrics>,
        bridge: Arc<dyn BridgeT>,
        processor: Arc<Processor>,
        analyzer: Analyzer,
    ) -> Self {
        Self {
            metrics,
            bridge,
            is_synced: Default::default(),
            processor,
            last_known_block: Mutex::new(None),
            target: Mutex::new(None),
            shutting_down: AtomicBool::new(false),
            analyzer,
            last_error_timestamp: AtomicU64::new(0),
        }
    }

    async fn sync_task(&self) {
        let sink = loop {
            let Ok(sink) = self
                .bridge
                .get_sink()
                .await
                .inspect(|sink| info!("got sink: {sink:?}"))
                .inspect_err(|e| {
                    let last_error_timestamp = self.last_error_timestamp.load(Ordering::SeqCst);
                    let now = std::time::SystemTime::now()
                        .duration_since(std::time::UNIX_EPOCH)
                        .unwrap()
                        .as_secs();
                    if now - last_error_timestamp > SYNC_ERROR_THRESHOLD_SECONDS {
                        error!("Failed to get sink: {:?}", e);
                        self.last_error_timestamp.store(now, Ordering::SeqCst);
                    }
                })
            else {
                tokio::time::sleep(std::time::Duration::from_secs(1)).await;
                continue;
            };
            break sink;
        };

        loop {
            let from = self
                .last_known_block
                .lock()
                .unwrap()
                .expect("last known block is not set");
            info!("Syncing from block: {:?}", from);
            let Ok(GetVirtualChainFromBlockV2Response {
                removed_chain_block_hashes,
                added_chain_block_hashes,
                chain_block_accepted_transactions,
            }) = self
                .bridge
                .get_historical_data(from.block_hash)
                .await
                .inspect_err(|e| error!("Failed to get historical data: {:?}", e))
            else {
                tokio::time::sleep(std::time::Duration::from_secs(1)).await;
                continue;
            };

            let target_is_reached = {
                let target = *self.target.lock().unwrap().get_or_insert_with(|| {
                    debug!("Setting target to sink {sink:?}");
                    sink
                });
                info!("Target: {:?}", target);
                if chain_block_accepted_transactions
                    .iter()
                    .any(|d| d.chain_block_header.blue_score.unwrap_or_default() >= target.blue_score)
                {
                    info!("added_chain_block_hashes contains target, target is reached");
                    true
                } else {
                    false
                }
            };
            let last_known_block = BlueScoredChainBlockHash {
                blue_score: chain_block_accepted_transactions
                    .last()
                    .and_then(|v| v.chain_block_header.blue_score)
                    .unwrap_or(from.blue_score),
                block_hash: chain_block_accepted_transactions
                    .last()
                    .and_then(|v| v.chain_block_header.hash)
                    .or_else(|| added_chain_block_hashes.last().copied())
                    .unwrap_or(from.block_hash),
            };

            let mergesets =
                process_acceptance_data(&chain_block_accepted_transactions, &self.analyzer);

            let notification = VirtualChainChanges {
                // who cares about that arc?? no one
                removed_chain_block_hashes,
                mergesets,
            };

            if target_is_reached {
                if let Err(err) = self
                    .processor
                    .send_historical_virtual_chain_changed_notification_and_apply_queue(
                        notification,
                    )
                    .map_err(|_| Error::SendError)
                {
                    error!("Failed to send historical notification: {:?}", err);
                    continue;
                }
            } else if let Err(err) = self
                .processor
                .send_historical_virtual_chain_changed_notification(notification)
                .map_err(|_| Error::SendError)
            {
                error!("Failed to send historical notification: {:?}", err);
                continue;
            }

            if let Some(v) = self.last_known_block.lock().unwrap().as_mut() {
                if last_known_block > *v {
                    *v = last_known_block;
                    debug!(target: "last_known_block_tracking", "Last known block is updated to: {:?}", last_known_block);
                }
            }

            debug!("Last known block is updated to: {:?}", last_known_block);

            if target_is_reached {
                info!("target is reached, state is synced");
                self.is_synced.store(true, Ordering::SeqCst);
                *self.target.lock().unwrap() = None;
                break;
            }
        }
    }

    fn spawn_sync_task_impl(self: &Arc<Self>) {
        // this should be implemented as a Service, since it is not
        // there are sequencing issues, and we need to ensure that
        // the sync task is not restarting when we are shutting down
        if self.shutting_down.load(std::sync::atomic::Ordering::SeqCst) {
            return;
        }

        info!("Spawning sync task");
        tokio::spawn({
            let this = self.clone();
            async move { this.sync_task().await }.instrument(tracing::info_span!("sync_task"))
        });
    }

    fn spawn_sync_task(self: &Arc<Self>, last_known_block: RpcHash) {
        let mut last_known_block_guard = self.last_known_block.lock().unwrap();
        if last_known_block_guard.is_some() {
            panic!("syncer is already initialized with last known block");
        }
        last_known_block_guard.replace(BlueScoredChainBlockHash {
            blue_score: 0,
            block_hash: last_known_block,
        });
        self.spawn_sync_task_impl();
    }
}

impl ConsumerT for Syncer {
    // temporarily (or permanently?) relocated to Processor from Nexus
    // to isolate Processor data ingest from Nexus logic allowing
    // Processor to receive notifications from different sources.
    #[instrument(skip_all)]
    fn handle_virtual_chain_changed(
        self: Arc<Self>,
        VirtualChainChangedNotification {
            removed_chain_block_hashes: _,
            added_chain_block_hashes: _,
            accepted_transaction_ids: _,
        }: VirtualChainChangedNotification,
    ) -> Result<()> {
        if self.is_synced.load(std::sync::atomic::Ordering::SeqCst) {
            self.processor
                .switch_to_queue_mod()
                .map_err(|_| Error::SendError)?;
            self.is_synced.store(false, Ordering::SeqCst);
            self.spawn_sync_task_impl();
        }

        Ok(())
    }

    fn disconnected(self: Arc<Self>) -> Result<()> {
        info!("Disconnected event is triggered");
        self.processor
            .switch_to_queue_mod()
            .map_err(|_| Error::SendError)?;
        self.is_synced.store(false, Ordering::SeqCst);
        if self.target.lock().unwrap().is_none() {
            self.spawn_sync_task_impl();
        }
        Ok(())
    }
}

pub fn process_acceptance_data(
    chain_block_accepted_transactions: &[RpcChainBlockAcceptedTransactions],
    analyzer: &Analyzer,
) -> Vec<Mergeset> {
    let mut collected_mergesets = Vec::new();

    for accepted in chain_block_accepted_transactions {
        let mut entropy_builder = MergesetEntropyBuilder::default();
        let accepting_block_blue_score = accepted.chain_block_header.blue_score.unwrap_or_default();
        let accepting_block_daa_score = accepted.chain_block_header.daa_score.unwrap_or_default();
        let accepted_chain_block_hash = accepted.chain_block_header.hash.unwrap_or_default();
        let mut merged_block_indexes = AHashMap::<RpcHash, usize>::new();
        let mut merged_block_tx_counts = AHashMap::<RpcHash, usize>::new();

        // Process transactions for operations
        let operations = accepted
            .accepted_transactions
            .iter()
            .filter_map(|rpc_tx| {
                let verbose_data = rpc_tx.verbose_data.as_ref();
                let merged_block_hash = verbose_data.and_then(|v| v.block_hash).unwrap_or_default();
                let block_time = verbose_data.and_then(|v| v.block_time).unwrap_or_default();
                let next_index = merged_block_indexes.len();
                let block_index_within_mergeset =
                    *merged_block_indexes.entry(merged_block_hash).or_insert_with(|| {
                        entropy_builder.add_block_hash(&merged_block_hash);
                        next_index
                    });
                let tx_index_within_merged_block =
                    merged_block_tx_counts.entry(merged_block_hash).or_default();
                let index_within_merged_block = *tx_index_within_merged_block;
                *tx_index_within_merged_block += 1;

                let fee = rpc_transaction_fee(rpc_tx);
                let tx = Transaction::try_from(rpc_tx.clone())
                    .inspect_err(|err| error!("failed to convert rpcTx to tx with err: {err}"))
                    .ok()?;
                let ctx_tx = ContextTransaction {
                    tx,
                    fee,
                    block_time,
                    accepting_block_daa_score,
                    index_within_merged_block,
                };

                analyzer
                    .detect_krc721(&ctx_tx)
                    .map_err(|err| (ctx_tx.tx.id(), err))
                    .inspect_err(|(txid, err)| {
                        error!("{txid} - detect krc721 error: {err}");
                        if let Some(db) = analyzer.db() {
                            let txid = *txid;
                            let reason = err.to_string();
                            let db = db.clone();
                            spawn_blocking(move || {
                                let mut wtx = db.write_tx();
                                _ = db.reject_tx(&mut wtx, txid, &reason).inspect_err(|err| {
                                    error!("failed to store transaction rejection in db: {err}")
                                });
                                let _ = wtx.commit().inspect_err(|err| {
                                    error!("failed to commit rejected transaction wtx in db: {err}")
                                });
                            });
                        }
                    })
                    .ok()
                    .flatten()
                    .map(|operation| MergesetOperation {
                        block_index_within_mergeset,
                        operation,
                        index_within_merged_block,
                    })
            })
            .collect();

        collected_mergesets.push(Mergeset {
            operations,
            entropy: entropy_builder.finalize(),
            blue_score: accepting_block_blue_score,
            accepted_chain_block_hash,
        });
    }

    collected_mergesets
}

fn rpc_transaction_fee(tx: &RpcOptionalTransaction) -> u64 {
    let input_sum = tx
        .inputs
        .iter()
        .filter_map(|input| input.verbose_data.as_ref())
        .filter_map(|verbose| verbose.utxo_entry.as_ref())
        .filter_map(|utxo| utxo.amount)
        .sum::<u64>();
    let output_sum = tx.outputs.iter().filter_map(|output| output.value).sum::<u64>();
    input_sum.saturating_sub(output_sum)
}

#[derive(Default)]
pub struct MergesetEntropyBuilder {
    entropy: u64,
}

impl MergesetEntropyBuilder {
    pub fn add_block_hash(&mut self, hash: &RpcHash) {
        // Process all 32 bytes of the hash in 8-byte chunks
        self.entropy = hash.as_bytes().chunks(8).fold(self.entropy, |accum, item| {
            accum ^ u64::from_le_bytes(item.try_into().unwrap())
        });
    }

    pub fn finalize(self) -> u64 {
        self.entropy
    }
}

pub trait SyncerT: Send + Sync + 'static {
    fn is_synced(&self) -> bool;
    fn last_known_block(&self) -> Option<BlueScoredChainBlockHash>;
    fn spawn(self: Arc<Self>, last_known_block: RpcHash);
    fn shutdown(&self);
}
