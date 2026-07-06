#!/usr/bin/env bash
#
# KRC-721 Indexer Automated Setup Script
# 
# This script automates the complete setup and sync process for the KRC-721 indexer:
# 1. Syncs the Kaspa node
# 2. Purges any existing database (safety)
# 3. Syncs indexer state from remote
# 4. Starts the full indexer with HTTP server
#
# Usage: ./setup-krc721-indexer.sh [--mainnet|--testnet-10] [--sync-url URL]
#
# The script can run unattended - you can close your SSH session and return later.
# All logs are saved to setup.log and step-specific log files.

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Default values
NETWORK="mainnet"
NETWORK_FLAG="--mainnet"
SYNC_URL="https://krc721.kat.foundation"

# Network-specific log directory to avoid conflicts when running multiple networks
# These are set after NETWORK is determined in parse_args
LOG_DIR=""
MAIN_LOG=""
STATUS_FILE=""
PID_FILE=""
BINARY_PATH="${PROJECT_ROOT}/target/release/krc721d"
MAX_SYNC_WAIT_HOURS=168  # 7 days max wait time
SYNC_CHECK_INTERVAL=30   # Check every 30 seconds

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --mainnet)
                NETWORK="mainnet"
                NETWORK_FLAG="--mainnet"
                SYNC_URL="https://krc721.kat.foundation"
                shift
                ;;
            --testnet-10)
                NETWORK="testnet-10"
                NETWORK_FLAG="--testnet-10"
                SYNC_URL="https://testnet-10.krc721.stream"
                shift
                ;;
            --sync-url)
                SYNC_URL="$2"
                shift 2
                ;;
            --binary-path)
                BINARY_PATH="$2"
                shift 2
                ;;
            -h|--help)
                echo "Usage: $0 [--mainnet|--testnet-10] [--sync-url URL] [--binary-path PATH]"
                echo ""
                echo "Options:"
                echo "  --mainnet          Use mainnet (default)"
                echo "  --testnet-10       Use testnet-10"
                echo "  --sync-url URL     Override sync URL"
                echo "  --binary-path PATH Override binary path"
                echo "  -h, --help         Show this help"
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                exit 1
                ;;
        esac
    done
}

# Logging functions
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "[${timestamp}] [${level}] ${message}" | tee -a "${MAIN_LOG}"
}

log_info() {
    log "INFO" "${BLUE}$*${NC}"
}

log_success() {
    log "SUCCESS" "${GREEN}$*${NC}"
}

log_warn() {
    log "WARN" "${YELLOW}$*${NC}"
}

log_error() {
    log "ERROR" "${RED}$*${NC}"
}

# Update status file
update_status() {
    echo "$1" > "${STATUS_FILE}"
    log_info "Status: $1"
}

# Cleanup function
cleanup() {
    local exit_code=$?
    
    # If script completed successfully (status is COMPLETE), don't stop the indexer
    if [[ -f "${STATUS_FILE}" ]] && grep -q "COMPLETE" "${STATUS_FILE}" 2>/dev/null; then
        # Script completed successfully - indexer should keep running
        exit $exit_code
    fi
    
    # Only stop krc721d on errors or interruptions
    if [[ -f "${PID_FILE}" ]]; then
        local pid=$(cat "${PID_FILE}")
        if kill -0 "${pid}" 2>/dev/null; then
            log_warn "Stopping krc721d process (PID: ${pid})..."
            kill "${pid}" 2>/dev/null || true
            sleep 2
            kill -9 "${pid}" 2>/dev/null || true
        fi
        rm -f "${PID_FILE}"
    fi
    if [[ $exit_code -ne 0 ]]; then
        log_error "Script exited with error code: ${exit_code}"
        update_status "FAILED: Error code ${exit_code}"
    fi
    exit $exit_code
}

# Setup trap for cleanup
trap cleanup EXIT INT TERM

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check binary exists
    if [[ ! -f "${BINARY_PATH}" ]]; then
        log_error "Binary not found: ${BINARY_PATH}"
        log_error "Please build the project first: cargo build --release"
        exit 1
    fi
    
    # Check binary is executable
    if [[ ! -x "${BINARY_PATH}" ]]; then
        log_warn "Making binary executable..."
        chmod +x "${BINARY_PATH}"
    fi
    
    # Check config file exists
    if [[ ! -f "${PROJECT_ROOT}/krc721d.toml" ]]; then
        log_error "Config file not found: ${PROJECT_ROOT}/krc721d.toml"
        exit 1
    fi
    
    # Check file descriptor limits
    local fd_limit=$(ulimit -n)
    if [[ $fd_limit -lt 8192 ]]; then
        log_warn "File descriptor limit is ${fd_limit} (recommended: 16384)"
        log_warn "Consider increasing with: ulimit -n 16384"
    fi
    
    log_success "Prerequisites check passed"
}

# Wait for node sync
wait_for_node_sync() {
    log_info "Starting Step 1: Syncing Kaspa node..."
    log_info "Note: Node persists data in ~/.krc721/kaspa/ and will catch up from where it left off."
    log_info "If this is a fresh start, initial sync may take hours or days."
    log_info "If resuming from a previous run, catch-up should be faster."
    
    local log_file="${LOG_DIR}/step1-node-sync.log"
    local start_time=$(date +%s)
    local max_wait_time=$((MAX_SYNC_WAIT_HOURS * 3600))
    
    # Start krc721d in background
    log_info "Starting krc721d with ${NETWORK_FLAG} --local..."
    "${BINARY_PATH}" ${NETWORK_FLAG} --local > "${log_file}" 2>&1 &
    local pid=$!
    echo "${pid}" > "${PID_FILE}"
    log_info "krc721d started with PID: ${pid}"
    
    # Monitor logs for sync completion
    log_info "Monitoring logs for 'SYNC: true'..."
    log_info "Note: 'SYNC: true' means the node has caught up to the current chain tip."
    log_info "Kaspa processes ~10 blocks/sec, so DAA score will increase continuously (this is normal)."
    local sync_found=false
    local sync_first_seen=0
    local sync_stable_seconds=5  # Require sync to be stable for 5 seconds
    local last_log_line=0
    local last_daa_score=""
    
    while true; do
        # Check if process is still running
        if ! kill -0 "${pid}" 2>/dev/null; then
            log_error "krc721d process died unexpectedly!"
            log_error "Last 50 lines of log:"
            tail -n 50 "${log_file}" | while IFS= read -r line; do
                log_error "  $line"
            done
            exit 1
        fi
        
        # Check elapsed time
        local elapsed=$(($(date +%s) - start_time))
        if [[ $elapsed -gt $max_wait_time ]]; then
            log_error "Maximum wait time (${MAX_SYNC_WAIT_HOURS} hours) exceeded!"
            log_error "Node may still be syncing. Check logs manually."
            exit 1
        fi
        
        # Read new log lines
        local line_count=$(wc -l < "${log_file}" 2>/dev/null || echo "0")
        if [[ $line_count -gt $last_log_line ]]; then
            # Use process substitution to avoid subshell issues with return
            while IFS= read -r line; do
                # Check for sync completion
                if echo "${line}" | grep -q "SYNC: true"; then
                    # Extract DAA score for informational purposes
                    local daa_score=$(echo "${line}" | grep -oE "DAA: [0-9]+" | grep -oE "[0-9]+" || echo "")
                    
                    if [[ "${sync_found}" == "false" ]]; then
                        # First time seeing SYNC: true
                        sync_found=true
                        sync_first_seen=$(date +%s)
                        last_daa_score="${daa_score}"
                        log_success "Node sync detected! Found: ${line}"
                        if [[ -n "${daa_score}" ]]; then
                            log_info "DAA Score: ${daa_score} (verifying sync is stable for ${sync_stable_seconds}s...)"
                            log_info "Note: DAA will continue increasing as blocks are processed (normal behavior)"
                        fi
                    elif [[ -n "${daa_score}" ]] && [[ "${daa_score}" != "${last_daa_score}" ]]; then
                        # DAA score changed - this is normal for a synced node, just log it
                        last_daa_score="${daa_score}"
                    fi
                fi
                # Log progress indicators
                if echo "${line}" | grep -qE "(IBD|Validating level|Processed.*blocks)"; then
                    log_info "Progress: ${line}"
                fi
            done < <(tail -n +$((last_log_line + 1)) "${log_file}")
            
            # Check if sync is stable
            # Note: We don't reset timer on DAA changes - DAA increases continuously on synced nodes
            if [[ "${sync_found}" == "true" ]]; then
                local sync_age=$(($(date +%s) - sync_first_seen))
                if [[ $sync_age -ge $sync_stable_seconds ]]; then
                    log_success "Node sync confirmed and stable! (stable for ${sync_age}s)"
                    if [[ -n "${last_daa_score}" ]]; then
                        log_info "DAA Score: ${last_daa_score} (will continue increasing as blocks are processed)"
                    fi
                    return 0
                fi
            fi
            
            last_log_line=$line_count
        fi
        
        # Show periodic status
        if [[ $((elapsed % 3600)) -eq 0 ]] && [[ $elapsed -gt 0 ]]; then
            local hours=$((elapsed / 3600))
            log_info "Still syncing... (${hours} hour(s) elapsed)"
        fi
        
        sleep "${SYNC_CHECK_INTERVAL}"
    done
}

# Stop krc721d process
stop_krc721d() {
    if [[ -f "${PID_FILE}" ]]; then
        local pid=$(cat "${PID_FILE}")
        if kill -0 "${pid}" 2>/dev/null; then
            log_info "Stopping krc721d process (PID: ${pid})..."
            kill "${pid}" 2>/dev/null || true
            sleep 5
            if kill -0 "${pid}" 2>/dev/null; then
                log_warn "Process didn't stop gracefully, forcing..."
                kill -9 "${pid}" 2>/dev/null || true
            fi
            log_success "krc721d stopped"
        fi
        rm -f "${PID_FILE}"
    fi
}

# Purge database
purge_database() {
    log_info "Starting Step 2a: Purging existing database (safety measure)..."
    
    local log_file="${LOG_DIR}/step2a-purge.log"
    if "${BINARY_PATH}" ${NETWORK_FLAG} --purge > "${log_file}" 2>&1; then
        log_success "Database purged successfully"
    else
        # Purge might fail if database doesn't exist, which is fine
        if grep -q "Database exists" "${log_file}" 2>/dev/null || \
           grep -q "no such file" "${log_file}" 2>/dev/null; then
            log_info "No existing database to purge (this is fine)"
        else
            log_warn "Purge command had issues, but continuing..."
            cat "${log_file}"
        fi
    fi
}

# Sync from remote indexer
sync_from_remote() {
    log_info "Starting Step 2b: Syncing indexer state from ${SYNC_URL}..."
    
    local log_file="${LOG_DIR}/step2b-sync.log"
    
    # Run sync command
    "${BINARY_PATH}" ${NETWORK_FLAG} --sync="${SYNC_URL}" > "${log_file}" 2>&1
    local exit_code=$?
    
    # Check for error messages in log (--sync returns 0 even on failure)
    if grep -q "Database exists" "${log_file}" 2>/dev/null; then
        log_error "Failed to sync: Database still exists after purge!"
        log_error "This means the purge didn't fully remove the database."
        log_error "Sync log:"
        cat "${log_file}"
        log_error ""
        log_error "Attempting manual database removal..."
        local db_folder="${HOME}/.krc721/${NETWORK}"
        if [[ -d "${db_folder}" ]]; then
            log_info "Removing database directory: ${db_folder}"
            rm -rf "${db_folder}"
            log_info "Retrying sync..."
            if "${BINARY_PATH}" ${NETWORK_FLAG} --sync="${SYNC_URL}" > "${log_file}" 2>&1; then
                if ! grep -q "Database exists" "${log_file}" 2>/dev/null; then
                    log_success "Indexer state synced successfully after manual cleanup"
                    return 0
                fi
            fi
        fi
        log_error "Sync failed even after manual cleanup. Please check logs."
        exit 1
    elif [[ $exit_code -ne 0 ]]; then
        log_error "Failed to sync from remote indexer (exit code: ${exit_code})!"
        log_error "Sync log:"
        tail -n 100 "${log_file}" | while IFS= read -r line; do
            log_error "  $line"
        done
        exit 1
    else
        # Check for success indicators
        if grep -qE "(Sync is complete|Restoring|Deploying snapshot)" "${log_file}" 2>/dev/null; then
            log_success "Indexer state synced successfully"
        else
            log_warn "Sync completed but no clear success message found. Checking log..."
            tail -n 20 "${log_file}" | while IFS= read -r line; do
                log_info "  $line"
            done
            log_success "Indexer state synced successfully"
        fi
    fi
}

# Start full indexer
start_full_indexer() {
    log_info "Starting Step 3: Starting full indexer with HTTP server..."
    
    local log_file="${LOG_DIR}/step3-indexer.log"
    log_info "Starting krc721d with ${NETWORK_FLAG} --local --http..."
    log_info "Logs will be written to: ${log_file}"
    log_info "You can monitor progress with: tail -f ${log_file}"
    
    # Start in background and save PID
    "${BINARY_PATH}" ${NETWORK_FLAG} --local --http > "${log_file}" 2>&1 &
    local pid=$!
    echo "${pid}" > "${PID_FILE}"
    log_info "krc721d started with PID: ${pid}"
    
    # Wait a bit and check if it's still running
    sleep 10
    if ! kill -0 "${pid}" 2>/dev/null; then
        log_error "Indexer failed to start!"
        log_error "Last 50 lines of log:"
        tail -n 50 "${log_file}" | while IFS= read -r line; do
            log_error "  $line"
        done
        exit 1
    fi
    
    log_success "Indexer started successfully!"
    log_info "The indexer is now running in the background."
    log_info "To stop it, run: kill \$(cat ${PID_FILE})"
    log_info "To view logs: tail -f ${log_file}"
    
    # Determine HTTP port
    local http_port="8800"
    if [[ "${NETWORK}" == "testnet-10" ]]; then
        http_port="8801"
    fi
    
    log_info ""
    log_success "=========================================="
    log_success "Setup Complete!"
    log_success "=========================================="
    log_info "Network: ${NETWORK}"
    log_info "HTTP Server: http://localhost:${http_port}"
    log_info "Process PID: ${pid}"
    log_info "Log file: ${log_file}"
    log_info "Status file: ${STATUS_FILE}"
    log_info ""
    log_info "You can now close your SSH session."
    log_info "The indexer will continue running in the background."
    log_success "=========================================="
}

# Main execution
main() {
    # Parse arguments first (before logging)
    parse_args "$@"
    
    # Set network-specific paths after NETWORK is determined
    LOG_DIR="${SCRIPT_DIR}/setup-logs-${NETWORK}"
    MAIN_LOG="${LOG_DIR}/setup.log"
    STATUS_FILE="${LOG_DIR}/status.txt"
    PID_FILE="${LOG_DIR}/krc721d.pid"
    
    # Create log directory
    mkdir -p "${LOG_DIR}"
    
    # Initialize log
    log_info "=========================================="
    log_info "KRC-721 Indexer Automated Setup"
    log_info "=========================================="
    log_info "Network: ${NETWORK}"
    log_info "Sync URL: ${SYNC_URL}"
    log_info "Binary: ${BINARY_PATH}"
    log_info "Started at: $(date)"
    log_info ""
    
    update_status "INITIALIZING"
    
    # Check prerequisites
    check_prerequisites
    
    # Step 1: Sync Kaspa node
    update_status "STEP1: SYNCING_KASPA_NODE"
    wait_for_node_sync
    stop_krc721d
    
    # Step 2a: Purge database
    update_status "STEP2A: PURGING_DATABASE"
    purge_database
    
    # Step 2b: Sync from remote
    update_status "STEP2B: SYNCING_FROM_REMOTE"
    sync_from_remote
    
    # Step 3: Start full indexer
    update_status "STEP3: STARTING_INDEXER"
    start_full_indexer
    
    update_status "COMPLETE"
    log_success "All steps completed successfully!"
}

# Run main function
main "$@"

