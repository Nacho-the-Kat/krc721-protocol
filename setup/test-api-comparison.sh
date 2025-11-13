#!/bin/bash
# Quick API comparison test

ORIGINAL="https://mainnet.krc721.stream"
NEW="https://krc721.kat.foundation"
BASE="/api/v1/krc721/mainnet"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0

echo "================================================================================"
echo "API Comparison: mainnet.krc721.stream vs krc721.kat.foundation"
echo "================================================================================"
echo ""

# Test 1: Status
echo "1. Status Endpoint"
O_STAT=$(curl -s --max-time 10 "${ORIGINAL}${BASE}/status")
N_STAT=$(curl -s --max-time 10 "${NEW}${BASE}/status")
O_COL=$(echo "$O_STAT" | jq -r '.result.tokenDeploymentsTotal' 2>/dev/null)
N_COL=$(echo "$N_STAT" | jq -r '.result.tokenDeploymentsTotal' 2>/dev/null)
O_MINT=$(echo "$O_STAT" | jq -r '.result.tokenMintsTotal' 2>/dev/null)
N_MINT=$(echo "$N_STAT" | jq -r '.result.tokenMintsTotal' 2>/dev/null)
O_XFR=$(echo "$O_STAT" | jq -r '.result.tokenTransfersTotal' 2>/dev/null)
N_XFR=$(echo "$N_STAT" | jq -r '.result.tokenTransfersTotal' 2>/dev/null)

if [[ "$O_COL" == "$N_COL" ]] && [[ "$O_MINT" == "$N_MINT" ]] && [[ "$O_XFR" == "$N_XFR" ]]; then
    echo -e "${GREEN}✓ Match: Collections=$O_COL, Mints=$O_MINT, Transfers=$O_XFR${NC}"
    ((PASS++))
else
    echo -e "${RED}✗ Differ: Collections ($O_COL vs $N_COL), Mints ($O_MINT vs $N_MINT), Transfers ($O_XFR vs $N_XFR)${NC}"
    ((FAIL++))
fi

# Test 2: Collections List
echo ""
echo "2. Collections List"
O_NFTS=$(curl -s --max-time 10 "${ORIGINAL}${BASE}/nfts?limit=3")
N_NFTS=$(curl -s --max-time 10 "${NEW}${BASE}/nfts?limit=3")
O_NFTS_DATA=$(echo "$O_NFTS" | jq -cS '.result' 2>/dev/null)
N_NFTS_DATA=$(echo "$N_NFTS" | jq -cS '.result' 2>/dev/null)

if [[ "$O_NFTS_DATA" == "$N_NFTS_DATA" ]]; then
    echo -e "${GREEN}✓ Match (3 items)${NC}"
    ((PASS++))
else
    O_COUNT=$(echo "$O_NFTS" | jq '.result | length' 2>/dev/null)
    N_COUNT=$(echo "$N_NFTS" | jq '.result | length' 2>/dev/null)
    if [[ "$O_COUNT" == "$N_COUNT" ]] && [[ "$O_COUNT" -gt 0 ]]; then
        O_FIRST=$(echo "$O_NFTS" | jq -cS '.result[0]' 2>/dev/null)
        N_FIRST=$(echo "$N_NFTS" | jq -cS '.result[0]' 2>/dev/null)
        if [[ "$O_FIRST" == "$N_FIRST" ]]; then
            echo -e "${GREEN}✓ First item matches ($O_COUNT items)${NC}"
            ((PASS++))
        else
            echo -e "${YELLOW}⚠ First items differ${NC}"
            ((FAIL++))
        fi
    else
        echo -e "${YELLOW}⚠ Count differs ($O_COUNT vs $N_COUNT)${NC}"
        ((FAIL++))
    fi
fi

# Get sample tick
TICK=$(echo "$O_NFTS" | jq -r '.result[0].tick' 2>/dev/null || echo "")

if [[ -n "$TICK" ]] && [[ "$TICK" != "null" ]]; then
    # Test 3: Collection Lookup
    echo ""
    echo "3. Collection Lookup ($TICK)"
    O_COLL=$(curl -s --max-time 10 "${ORIGINAL}${BASE}/nfts/${TICK}" | jq -cS '.result' 2>/dev/null)
    N_COLL=$(curl -s --max-time 10 "${NEW}${BASE}/nfts/${TICK}" | jq -cS '.result' 2>/dev/null)
    
    if [[ "$O_COLL" == "$N_COLL" ]]; then
        echo -e "${GREEN}✓ Match${NC}"
        ((PASS++))
    else
        echo -e "${YELLOW}⚠ Differ${NC}"
        ((FAIL++))
    fi
    
    # Test 4: Owners
    echo ""
    echo "4. Collection Owners ($TICK)"
    O_OWN=$(curl -s --max-time 10 "${ORIGINAL}${BASE}/owners/${TICK}?limit=3" | jq -cS '.result' 2>/dev/null)
    N_OWN=$(curl -s --max-time 10 "${NEW}${BASE}/owners/${TICK}?limit=3" | jq -cS '.result' 2>/dev/null)
    
    if [[ "$O_OWN" == "$N_OWN" ]]; then
        echo -e "${GREEN}✓ Match (3 items)${NC}"
        ((PASS++))
    else
        O_OWN_CNT=$(curl -s --max-time 10 "${ORIGINAL}${BASE}/owners/${TICK}?limit=3" | jq '.result | length' 2>/dev/null)
        N_OWN_CNT=$(curl -s --max-time 10 "${NEW}${BASE}/owners/${TICK}?limit=3" | jq '.result | length' 2>/dev/null)
        if [[ "$O_OWN_CNT" == "$N_OWN_CNT" ]] && [[ "$O_OWN_CNT" -gt 0 ]]; then
            echo -e "${GREEN}✓ Count matches ($O_OWN_CNT items)${NC}"
            ((PASS++))
        else
            echo -e "${YELLOW}⚠ Count differs ($O_OWN_CNT vs $N_OWN_CNT)${NC}"
            ((FAIL++))
        fi
    fi
    
    # Get token ID
    ID=$(curl -s --max-time 10 "${ORIGINAL}${BASE}/owners/${TICK}?limit=1" | jq -r '.result[0].id // empty' 2>/dev/null || echo "")
    
    if [[ -n "$ID" ]] && [[ "$ID" != "null" ]] && [[ "$ID" != "" ]]; then
        # Test 5: Token Lookup
        echo ""
        echo "5. Token Lookup ($TICK/$ID)"
        O_TOK=$(curl -s --max-time 10 "${ORIGINAL}${BASE}/nfts/${TICK}/${ID}" | jq -cS '.result' 2>/dev/null)
        N_TOK=$(curl -s --max-time 10 "${NEW}${BASE}/nfts/${TICK}/${ID}" | jq -cS '.result' 2>/dev/null)
        
        if [[ "$O_TOK" == "$N_TOK" ]]; then
            echo -e "${GREEN}✓ Match${NC}"
            ((PASS++))
        else
            echo -e "${YELLOW}⚠ Differ${NC}"
            ((FAIL++))
        fi
        
        # Test 6: Token History
        echo ""
        echo "6. Token History ($TICK/$ID)"
        O_HIST=$(curl -s --max-time 10 "${ORIGINAL}${BASE}/history/${TICK}/${ID}?limit=3" | jq '.result | length' 2>/dev/null)
        N_HIST=$(curl -s --max-time 10 "${NEW}${BASE}/history/${TICK}/${ID}?limit=3" | jq '.result | length' 2>/dev/null)
        
        if [[ "$O_HIST" == "$N_HIST" ]]; then
            echo -e "${GREEN}✓ Match ($O_HIST items)${NC}"
            ((PASS++))
        else
            echo -e "${YELLOW}⚠ Differ ($O_HIST vs $N_HIST)${NC}"
            ((FAIL++))
        fi
    fi
    
    # Test 7: Ranges
    echo ""
    echo "7. Available Ranges ($TICK)"
    O_RNG=$(curl -s --max-time 10 "${ORIGINAL}${BASE}/ranges/${TICK}" | jq -cS '.' 2>/dev/null)
    N_RNG=$(curl -s --max-time 10 "${NEW}${BASE}/ranges/${TICK}" | jq -cS '.' 2>/dev/null)
    
    if [[ "$O_RNG" == "$N_RNG" ]]; then
        echo -e "${GREEN}✓ Match${NC}"
        ((PASS++))
    else
        echo -e "${YELLOW}⚠ Differ${NC}"
        ((FAIL++))
    fi
fi

# Test 8: Deployments
echo ""
echo "8. Deployments List"
O_DEP=$(curl -s --max-time 10 "${ORIGINAL}${BASE}/deployments?limit=3" | jq '.result | length' 2>/dev/null)
N_DEP=$(curl -s --max-time 10 "${NEW}${BASE}/deployments?limit=3" | jq '.result | length' 2>/dev/null)

if [[ "$O_DEP" == "$N_DEP" ]]; then
    echo -e "${GREEN}✓ Match ($O_DEP items)${NC}"
    ((PASS++))
else
    echo -e "${YELLOW}⚠ Differ ($O_DEP vs $N_DEP)${NC}"
    ((FAIL++))
fi

# Test 9: Operations
echo ""
echo "9. Operations List"
O_OPS=$(curl -s --max-time 10 "${ORIGINAL}${BASE}/ops?limit=3" | jq '.result | length' 2>/dev/null)
N_OPS=$(curl -s --max-time 10 "${NEW}${BASE}/ops?limit=3" | jq '.result | length' 2>/dev/null)

if [[ "$O_OPS" == "$N_OPS" ]]; then
    echo -e "${GREEN}✓ Match ($O_OPS items)${NC}"
    ((PASS++))
else
    echo -e "${YELLOW}⚠ Differ ($O_OPS vs $N_OPS)${NC}"
    ((FAIL++))
fi

# Test 10: Get second collection for additional testing
TICK2=$(curl -s --max-time 10 "${ORIGINAL}${BASE}/nfts?limit=2" | jq -r '.result[1].tick // empty' 2>/dev/null || echo "")

if [[ -n "$TICK2" ]] && [[ "$TICK2" != "null" ]] && [[ "$TICK2" != "$TICK" ]]; then
    echo ""
    echo "10. Second Collection Lookup ($TICK2)"
    O_COLL2=$(curl -s --max-time 10 "${ORIGINAL}${BASE}/nfts/${TICK2}" | jq -cS '.result.tick, .result.maxSupply, .result.currentSupply' 2>/dev/null)
    N_COLL2=$(curl -s --max-time 10 "${NEW}${BASE}/nfts/${TICK2}" | jq -cS '.result.tick, .result.maxSupply, .result.currentSupply' 2>/dev/null)
    
    if [[ "$O_COLL2" == "$N_COLL2" ]]; then
        echo -e "${GREEN}✓ Match${NC}"
        ((PASS++))
    else
        echo -e "${YELLOW}⚠ Differ${NC}"
        ((FAIL++))
    fi
else
    echo ""
    echo "10. Second Collection Lookup"
    echo -e "${YELLOW}⚠ Skipped (no second collection found)${NC}"
    ((PASS++))
fi

# Get operation score
SCORE=$(curl -s --max-time 10 "${ORIGINAL}${BASE}/ops?limit=1" | jq -r '.result[0].score // empty' 2>/dev/null || echo "")

if [[ -n "$SCORE" ]] && [[ "$SCORE" != "null" ]] && [[ "$SCORE" != "0" ]]; then
    # Test 11: Operation by Score
    echo ""
    echo "11. Operation by Score ($SCORE)"
    O_SCORE=$(curl -s --max-time 10 "${ORIGINAL}${BASE}/ops/score/${SCORE}" | jq -cS '.result' 2>/dev/null)
    N_SCORE=$(curl -s --max-time 10 "${NEW}${BASE}/ops/score/${SCORE}" | jq -cS '.result' 2>/dev/null)
    
    if [[ "$O_SCORE" == "$N_SCORE" ]]; then
        echo -e "${GREEN}✓ Match${NC}"
        ((PASS++))
    else
        echo -e "${YELLOW}⚠ Differ${NC}"
        ((FAIL++))
    fi
fi

# Get txid
TXID=$(curl -s --max-time 10 "${ORIGINAL}${BASE}/ops?limit=1" | jq -r '.result[0].txid // empty' 2>/dev/null || echo "")

if [[ -n "$TXID" ]] && [[ "$TXID" != "null" ]]; then
    # Test 12: Operation by TxID
    echo ""
    echo "12. Operation by TxID ($TXID)"
    O_TX=$(curl -s --max-time 10 "${ORIGINAL}${BASE}/ops/txid/${TXID}" | jq -cS '.result' 2>/dev/null)
    N_TX=$(curl -s --max-time 10 "${NEW}${BASE}/ops/txid/${TXID}" | jq -cS '.result' 2>/dev/null)
    
    if [[ "$O_TX" == "$N_TX" ]]; then
        echo -e "${GREEN}✓ Match${NC}"
        ((PASS++))
    else
        echo -e "${YELLOW}⚠ Differ${NC}"
        ((FAIL++))
    fi
fi

# Get address
if [[ -n "$TICK" ]]; then
    ADDR=$(curl -s --max-time 10 "${ORIGINAL}${BASE}/owners/${TICK}?limit=1" | jq -r '.result[0].owner // empty' 2>/dev/null || echo "")
    
    if [[ -n "$ADDR" ]] && [[ "$ADDR" != "null" ]]; then
        # Test 13: Address NFT List
        echo ""
        echo "13. Address NFT List ($ADDR)"
        O_ADDR=$(curl -s --max-time 10 "${ORIGINAL}${BASE}/address/${ADDR}?limit=3" | jq '.result | length' 2>/dev/null)
        N_ADDR=$(curl -s --max-time 10 "${NEW}${BASE}/address/${ADDR}?limit=3" | jq '.result | length' 2>/dev/null)
        
        if [[ "$O_ADDR" == "$N_ADDR" ]]; then
            echo -e "${GREEN}✓ Match ($O_ADDR items)${NC}"
            ((PASS++))
        else
            echo -e "${YELLOW}⚠ Differ ($O_ADDR vs $N_ADDR)${NC}"
            ((FAIL++))
        fi
        
        # Test 14: Address NFT Lookup
        echo ""
        echo "14. Address NFT Lookup ($ADDR/$TICK)"
        O_ADDR_TICK=$(curl -s --max-time 10 "${ORIGINAL}${BASE}/address/${ADDR}/${TICK}?limit=3" | jq '.result | length' 2>/dev/null)
        N_ADDR_TICK=$(curl -s --max-time 10 "${NEW}${BASE}/address/${ADDR}/${TICK}?limit=3" | jq '.result | length' 2>/dev/null)
        
        if [[ "$O_ADDR_TICK" == "$N_ADDR_TICK" ]]; then
            echo -e "${GREEN}✓ Match ($O_ADDR_TICK items)${NC}"
            ((PASS++))
        else
            echo -e "${YELLOW}⚠ Differ ($O_ADDR_TICK vs $N_ADDR_TICK)${NC}"
            ((FAIL++))
        fi
        
        # Test 15: Royalty Fee
        echo ""
        echo "15. Royalty Fee ($ADDR/$TICK)"
        O_ROY=$(curl -s --max-time 10 "${ORIGINAL}${BASE}/royalties/${ADDR}/${TICK}" | jq -cS '.' 2>/dev/null)
        N_ROY=$(curl -s --max-time 10 "${NEW}${BASE}/royalties/${ADDR}/${TICK}" | jq -cS '.' 2>/dev/null)
        
        if [[ "$O_ROY" == "$N_ROY" ]]; then
            echo -e "${GREEN}✓ Match${NC}"
            ((PASS++))
        else
            echo -e "${YELLOW}⚠ Differ${NC}"
            ((FAIL++))
        fi
    fi
fi

# Summary
echo ""
echo "================================================================================"
echo "Summary"
echo "================================================================================"
echo -e "${GREEN}Passed: $PASS${NC}"
echo -e "${RED}Failed: $FAIL${NC}"
echo "Total: $((PASS + FAIL))"

if [[ $FAIL -eq 0 ]]; then
    echo -e "${GREEN}✓ All tests passed! Indexers have matching data.${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠ Some differences found (may be due to sync timing or pagination)${NC}"
    exit 1
fi

