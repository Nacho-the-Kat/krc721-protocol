#!/usr/bin/env bash
#
# KRC-721 Indexer Control Script
# 
# Helper script to check status and manage the running indexer(s)
#
# Usage:
#   ./krc721-indexer-ctl.sh status [--mainnet|--testnet-10]    - Check current status
#   ./krc721-indexer-ctl.sh stop [--mainnet|--testnet-10]      - Stop the running indexer
#   ./krc721-indexer-ctl.sh logs [--mainnet|--testnet-10]      - Show recent logs
#   ./krc721-indexer-ctl.sh tail [--mainnet|--testnet-10]      - Tail logs in real-time
#   ./krc721-indexer-ctl.sh list                               - List all running indexers

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default network (can be overridden by argument)
NETWORK=""
LOG_DIR=""
PID_FILE=""
STATUS_FILE=""

# Colors
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Parse network argument
parse_network() {
    NETWORK=""
    for arg in "$@"; do
        case "$arg" in
            --mainnet)
                NETWORK="mainnet"
                ;;
            --testnet-10)
                NETWORK="testnet-10"
                ;;
        esac
    done
    
    # If no network specified, try to detect from running processes
    if [[ -z "$NETWORK" ]]; then
        # Check for mainnet
        if ps aux | grep -q "krc721d.*--mainnet.*--http" | grep -v grep; then
            NETWORK="mainnet"
        # Check for testnet-10
        elif ps aux | grep -q "krc721d.*--testnet-10.*--http" | grep -v grep; then
            NETWORK="testnet-10"
        else
            # Default to mainnet if nothing running
            NETWORK="mainnet"
        fi
    fi
    
    LOG_DIR="${SCRIPT_DIR}/setup-logs-${NETWORK}"
    PID_FILE="${LOG_DIR}/krc721d.pid"
    STATUS_FILE="${LOG_DIR}/status.txt"
}

list_indexers() {
    echo -e "${BLUE}=== Running KRC-721 Indexers ===${NC}"
    echo ""
    
    local found=false
    
    for network in mainnet testnet-10; do
        local log_dir="${SCRIPT_DIR}/setup-logs-${network}"
        local pid_file="${log_dir}/krc721d.pid"
        
        if [[ -f "${pid_file}" ]]; then
            local pid=$(cat "${pid_file}")
            if kill -0 "${pid}" 2>/dev/null; then
                found=true
                echo -e "${GREEN}${network^}${NC} (PID: ${pid})"
                
                # Get HTTP port
                local port="8800"
                if [[ "$network" == "testnet-10" ]]; then
                    port="8801"
                fi
                
                # Check if HTTP server is responding
                if curl -s "http://localhost:${port}/api/v1/krc721/${network}/status" >/dev/null 2>&1; then
                    echo -e "  HTTP: ${GREEN}http://localhost:${port}${NC} ✓"
                else
                    echo -e "  HTTP: ${YELLOW}http://localhost:${port}${NC} (not responding)"
                fi
                
                # Show status
                if [[ -f "${log_dir}/status.txt" ]]; then
                    local status=$(cat "${log_dir}/status.txt")
                    echo -e "  Status: ${status}"
                fi
                
                echo ""
            fi
        fi
    done
    
    if [[ "$found" == "false" ]]; then
        echo -e "${YELLOW}No running indexers found${NC}"
    fi
}

show_status() {
    parse_network "$@"
    
    echo -e "${BLUE}=== KRC-721 Indexer Status (${NETWORK}) ===${NC}"
    echo ""
    
    if [[ -f "${STATUS_FILE}" ]]; then
        local status=$(cat "${STATUS_FILE}")
        echo -e "Setup Status: ${GREEN}${status}${NC}"
    else
        echo -e "Setup Status: ${YELLOW}Unknown${NC}"
    fi
    echo ""
    
    if [[ -f "${PID_FILE}" ]]; then
        local pid=$(cat "${PID_FILE}")
        if kill -0 "${pid}" 2>/dev/null; then
            echo -e "Process Status: ${GREEN}Running${NC} (PID: ${pid})"
            
            # Try to determine which step is running
            local log_file="${LOG_DIR}/step3-indexer.log"
            if [[ -f "${log_file}" ]]; then
                echo -e "Mode: ${GREEN}Full Indexer${NC}"
                echo -e "Log File: ${log_file}"
            else
                log_file="${LOG_DIR}/step1-node-sync.log"
                if [[ -f "${log_file}" ]]; then
                    echo -e "Mode: ${YELLOW}Node Sync${NC}"
                    echo -e "Log File: ${log_file}"
                fi
            fi
            
            # Show process info
            if command -v ps >/dev/null 2>&1; then
                echo ""
                echo "Process Info:"
                ps -p "${pid}" -o pid,ppid,cmd,etime,pcpu,pmem 2>/dev/null || true
            fi
        else
            echo -e "Process Status: ${RED}Not Running${NC} (stale PID file)"
            echo -e "PID file exists but process ${pid} is not running"
        fi
    else
        echo -e "Process Status: ${RED}Not Running${NC}"
        echo -e "No PID file found"
    fi
    echo ""
}

stop_indexer() {
    parse_network "$@"
    
    echo -e "${BLUE}Stopping ${NETWORK} indexer...${NC}"
    
    if [[ ! -f "${PID_FILE}" ]]; then
        echo -e "${YELLOW}No PID file found for ${NETWORK}. Indexer may not be running.${NC}"
        exit 0
    fi
    
    local pid=$(cat "${PID_FILE}")
    if ! kill -0 "${pid}" 2>/dev/null; then
        echo -e "${YELLOW}Process ${pid} is not running. Removing stale PID file.${NC}"
        rm -f "${PID_FILE}"
        exit 0
    fi
    
    echo -e "${BLUE}Stopping krc721d (PID: ${pid})...${NC}"
    kill "${pid}" 2>/dev/null || true
    
    # Wait for graceful shutdown
    for i in {1..10}; do
        if ! kill -0 "${pid}" 2>/dev/null; then
            echo -e "${GREEN}Indexer stopped gracefully${NC}"
            rm -f "${PID_FILE}"
            exit 0
        fi
        sleep 1
    done
    
    # Force kill if still running
    if kill -0 "${pid}" 2>/dev/null; then
        echo -e "${YELLOW}Process didn't stop gracefully, forcing...${NC}"
        kill -9 "${pid}" 2>/dev/null || true
        sleep 1
        rm -f "${PID_FILE}"
        echo -e "${GREEN}Indexer stopped${NC}"
    fi
}

show_logs() {
    parse_network "$@"
    
    local log_file="${LOG_DIR}/step3-indexer.log"
    if [[ ! -f "${log_file}" ]]; then
        log_file="${LOG_DIR}/step1-node-sync.log"
    fi
    
    if [[ ! -f "${log_file}" ]]; then
        echo -e "${RED}No log file found for ${NETWORK}${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}Showing last 50 lines of: ${log_file}${NC}"
    echo ""
    tail -n 50 "${log_file}"
}

tail_logs() {
    parse_network "$@"
    
    local log_file="${LOG_DIR}/step3-indexer.log"
    if [[ ! -f "${log_file}" ]]; then
        log_file="${LOG_DIR}/step1-node-sync.log"
    fi
    
    if [[ ! -f "${log_file}" ]]; then
        echo -e "${RED}No log file found for ${NETWORK}${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}Tailing logs: ${log_file}${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
    echo ""
    tail -f "${log_file}"
}

case "${1:-status}" in
    status)
        shift
        show_status "$@"
        ;;
    stop)
        shift
        stop_indexer "$@"
        ;;
    logs)
        shift
        show_logs "$@"
        ;;
    tail)
        shift
        tail_logs "$@"
        ;;
    list)
        list_indexers
        ;;
    *)
        echo "Usage: $0 {status|stop|logs|tail|list} [--mainnet|--testnet-10]"
        echo ""
        echo "Commands:"
        echo "  status [--mainnet|--testnet-10]  - Show current status (auto-detects if not specified)"
        echo "  stop [--mainnet|--testnet-10]    - Stop the running indexer"
        echo "  logs [--mainnet|--testnet-10]    - Show recent logs"
        echo "  tail [--mainnet|--testnet-10]    - Tail logs in real-time"
        echo "  list                              - List all running indexers"
        exit 1
        ;;
esac

