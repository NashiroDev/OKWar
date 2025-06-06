from flask import Flask, request
import json
from web3 import Web3, HTTPProvider
from apscheduler.schedulers.background import BackgroundScheduler
import threading
import time
import os
from dotenv import load_dotenv

app = Flask(__name__)

# Configuration
BOARD_SIZE = (170, 100)  # Board dimensions: 170 columns x 100 rows
COLORS = ["white", "black", "gray", "silver", "maroon", "red", "purple", "fuscia", "green", "lime", "olive", "yellow", "navy", "blue", "teal", "aqua"]
color_to_num = {color: i for i, color in enumerate(COLORS)}  # Maps color names to numbers (0-15)

# In-memory data structures
grids = [[[0] * BOARD_SIZE[0] for _ in range(BOARD_SIZE[1])] for _ in range(4)]  # 4 boards, each 100x170
address_counts = [{} for _ in range(4)]  # Address activity per board
last_push_times = [0] * 4  # Timestamp of last successful push per board
updates_flags = [False] * 4  # Flags indicating if a board has updates
gas_prices = [int(1e6)] * 4  # Gas price per board, starting at 1,000,000 wei

lock = threading.Lock()  # Thread safety for concurrent updates

# Load initial state from files
for board_id in range(4):
    board_file = f"board{board_id}.txt"
    if os.path.exists(board_file):
        with open(board_file, "r") as f:
            lines = f.readlines()
            for y, line in enumerate(lines[:100]):
                for x, c in enumerate(line.strip()[:170]):
                    grids[board_id][y][x] = int(c, 16)  # Load hex color values
    address_file = f"address{board_id}.json"
    if os.path.exists(address_file):
        with open(address_file, "r") as f:
            address_counts[board_id] = json.load(f)  # Load address activity

# Webhook endpoint for Alchemy events
@app.route('/webhook', methods=['POST'])
def webhook():
    """
    Receives PixelSet events from Alchemy webhooks and updates board state and address activity.
    Expected event format: {'event': {'args': {'boardId': int, 'x': int, 'y': int, 'color': str, 'owner': str}}}
    """
    data = request.json
    event = data['event']
    board_id = event['args']['boardId']
    x = event['args']['x']
    y = event['args']['y']
    color = event['args']['color']
    owner = event['args']['owner']

    with lock:
        # Update board grid
        color_num = color_to_num[color]
        grids[board_id][y][x] = color_num
        updates_flags[board_id] = True

        # Update address activity
        address_counts[board_id][owner] = address_counts[board_id].get(owner, 0) + 1

        # Write addressX.json immediately to prevent data loss
        with open(f"address{board_id}.json", "w") as f:
            json.dump(address_counts[board_id], f)

        # Debug: Log event details without large data
        print(f"Processed event for board {board_id}, cell ({x},{y}), color {color}, owner {owner[:10]}...")

    return '', 200  # Empty response with success status

# Generate HTML for a board
def generate_html(board_id):
    """
    Creates an HTML string by embedding the board's pixel data into a template.
    Pixel data is a string of 17,000 characters (0-15), encoded as Unicode code points.
    """
    with lock:
        # Convert grid to a 2D array string: [[0,0,...],[0,0,...],...]
        board_data_str = '[' + ','.join(['[' + ','.join(map(str, row)) + ']' for row in grids[board_id]]) + ']'
        with open("pixelboard_template.html", "r") as f:
            template = f.read()
        html = template.replace("<!--BOARD_DATA-->", board_data_str).replace("<!--BOARD_ID-->", str(board_id))
        with open(f"board{board_id}.html", "w") as f:
            f.write(html)
    print(f"Generated HTML for board {board_id}, data length: {len(board_data_str)}")
    return html

# Push HTML to OKComputerStore contract
def push_to_contract(board_id, html):
    """
    Sends the HTML string to the OKComputerStore contract using the storeString function.
    Tries multiple RPC endpoints and adjusts gas price on failure.
    """
    token_id = token_ids[board_id]
    private_key = private_keys[board_id]
    key = "0xfc77a78c81db9794340a10dbcb0632f44d2d889f2cac2911b039a50f90ead7d0"  # Fixed key
    current_gas_price = gas_prices[board_id]

    for rpc_url in rpc_urls:
        w3 = Web3(HTTPProvider(rpc_url))
        if not w3.is_connected():
            print(f"RPC {rpc_url} is not connected, skipping...")
            continue
        account = w3.eth.account.from_key(private_key)
        contract = w3.eth.contract(address=contract_address, abi=contract_abi)
        tx = contract.functions.storeString(token_id, key, html).build_transaction({
            'from': account.address,
            'gas': 2000000,
            'gasPrice': current_gas_price,
            'nonce': w3.eth.get_transaction_count(account.address),
        })
        signed_tx = account.sign_transaction(tx)
        try:
            tx_hash = w3.eth.send_raw_transaction(signed_tx.rawTransaction)
            receipt = w3.eth.wait_for_transaction_receipt(tx_hash, timeout=120)
            if receipt.status == 1:
                gas_prices[board_id] = int(1e6)  # Reset gas price on success
                print(f"Successfully pushed HTML for board {board_id} via {rpc_url}")
                return True
            else:
                print(f"Transaction failed for board {board_id} via {rpc_url}")
        except Exception as e:
            print(f"Error pushing to contract for board {board_id} via {rpc_url}: {e}")
    # Increase gas price if all RPCs fail (up to 5e6 wei)
    if current_gas_price < int(5e6):
        gas_prices[board_id] += int(1e6)
        print(f"Increased gas price for board {board_id} to {gas_prices[board_id]}")
    return False

# Scheduled job to push updates every minute
def update_job():
    """Checks for board updates every minute and pushes HTML to the contract if needed."""
    for board_id in range(4):
        if updates_flags[board_id]:
            with lock:
                # Write current board state to file
                with open(f"board{board_id}.txt", "w") as f:
                    for y in range(100):
                        f.write(''.join(f"{color:x}" for color in grids[board_id][y]) + "\n")
                html = generate_html(board_id)
                success = push_to_contract(board_id, html)
                if success:
                    updates_flags[board_id] = False
                    last_push_times[board_id] = time.time()
                    print(f"Successfully updated board {board_id}")
                else:
                    print(f"Failed to update board {board_id}, retrying next cycle")

# Load environment variables
load_dotenv()
rpc_urls = os.getenv("RPC_URLS").split(",")
private_keys = os.getenv("PRIVATE_KEYS").split(",")
token_ids = list(map(int, os.getenv("TOKEN_IDS").split(",")))
contract_address = os.getenv("CONTRACT_ADDRESS")
pixelboard_address = os.getenv("PIXELBOARD_ADDRESS")

# OKComputerStore contract ABI
contract_abi = [
    {
        "inputs": [
            {"internalType": "uint256", "name": "tokenId", "type": "uint256"},
            {"internalType": "bytes32", "name": "key", "type": "bytes32"},
            {"internalType": "string", "name": "data", "type": "string"}
        ],
        "name": "storeString",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    }
]

# Start the scheduler
scheduler = BackgroundScheduler()
scheduler.add_job(update_job, 'interval', minutes=1)
scheduler.start()

if __name__ == '__main__':
    print("Starting Flask server...")
    app.run(port=5000)