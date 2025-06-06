<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
</head>
<body>
  <h1>PixelBoard Project</h1>
  <h2>Project Overview</h2>
  <div class="section">
    <p><span class="bold">PixelBoard</span> is an interactive, on-chain collaborative pixel canvas built as a smart contract with live updates. Community members can buy, color, and update pixels on one of four massive 170x100 boards, with every change recorded immutably on the blockchain. Each cell stores its owner, color, and edit count. The experience is completed by a live HTML front-end and real-time tracking via an event-driven Python backend.</p>
  </div>
  <h2>Key Components</h2>
  <div class="section">
    <ul>
      <li><b>Smart Contract (<code>pixelBoard</code>)</b>: Solidity contract managing 4 boards of 170x100 cells, pixel ownership, edition count, color validation, payments, and pixel update events.</li>
      <li><b>Python Bot</b>: Listens to contract events (via Alchemy webhooks), updates board state and address activity JSONs, and pushes real-time HTML data to the OKComputerStore contract for public display.</li>
      <li><b>Frontend (HTML)</b>: Pure HTML/CSS/JS (no dependencies) rendering a responsive pixel canvas with editing, color selection, and direct contract interaction instructions.</li>
    </ul>
  </div>
  <h2>How It Works</h2>
  <div class="section">
    <ol>
      <li>Users interact with the front-end to choose a pixel/cell, select a color, and submit a transaction using the <code>setPixel</code> function. The price of each cell rises by 15% per edit.</li>
      <li>The contract validates the color, updates cell ownership/edition, tracks per-user stats, and emits an event.</li>
      <li>The Python bot listens for these events, updates the local board and user stats files, and generates a compact HTML board snapshot pushed on-chain to OKComputerStore for live display.</li>
    </ol>
  </div>
  <h2>Interacting With PixelBoard</h2>
  <div class="section">
    <ol>
      <li>Go to the live PixelBoard HTML front-end (as linked in project docs or contract).</li>
      <li>View the latest board state. Select any cell to preview info or begin editing. To place a pixel:
        <ul>
          <li>Call <code>setPixel</code> on the PixelBoard contract with the right board ID, X/Y coordinates, and color string (see allowed colors below). Data should be base64-encoded as: <code>(uint8 boardId, uint256 x, uint256 y, string color)</code>.</li>
          <li>Pay the ETH cost (calculated via <code>getPixelCost</code>), which rises with cell edition number.</li>
        </ul>
      </li>
      <li>Multi-pixel edits: Use the board chunk tool in the HTML front-end to select and update several cells. The contract supports batch edits via a dedicated function (<code>setPixels</code>).</li>
      <li>Events update the display every 1-2 minutes. Refresh the page to see your changes.</li>
    </ol>
  </div>
  <h2>Allowed Colors</h2>
  <div class="section">
    <code>black</code>, <code>white</code>, <code>gray</code>, <code>silver</code>, <code>maroon</code>, <code>red</code>, <code>purple</code>, <code>fuscia</code>, <code>green</code>, <code>lime</code>, <code>olive</code>, <code>yellow</code>, <code>navy</code>, <code>blue</code>, <code>teal</code>, <code>aqua</code>
  </div>
  <h2>Developer Quickstart</h2>
  <div class="section">
    <ol>
      <li>Deploy the <b>pixelBoard</b> Solidity contract to your preferred EVM chain (Base is recommended). Use the latest Solidity compiler (v0.8.x+).</li>
      <li>Verify contract source code on block explorer for transparency.</li>
      <li>Configure the Python bot with your Alchemy webhook, private keys, and RPC endpoints in the <code>.env</code> file. Run it to start syncing events and publishing HTML to OKComputerStore.</li>
      <li>Edit, fork, or deploy the HTML front-end. No external dependencies—copy-paste is enough. See <code>frontend.html</code> for structure.</li>
    </ol>
  </div>
  <h2>Tips & Notes</h2>
  <div class="tip">
    <ul>
      <li>PixelBoard is fully on-chain: all actions are tracked, verifiable, and open for audit.</li>
      <li>Each contract function is carefully access-controlled. <code>pause</code> and <code>retrieveEth</code> are owner-only.</li>
      <li>Overpaying for pixel edits? Excess ETH is always refunded by the contract logic.</li>
      <li>All on-chain HTML updates are capped at 64KB for gas efficiency. Data is minified and color-coded for fast load.</li>
    </ul>
  </div>
  <h2>Links</h2>
  <div class="section">
    <ul>
      <li><b>Smart Contract:</b> See <code>pixelBoard.sol</code></li>
      <li><b>Python Bot:</b> See <code>bot.py</code></li>
      <li><b>Frontend HTML:</b> See <code>frontend.html</code></li>
    </ul>
  </div>
</body>
</html>
