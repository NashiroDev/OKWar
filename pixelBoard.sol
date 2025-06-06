// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";

contract PixelBoard is Ownable {
    struct Cell {
        address owner;
        string color;
        uint256 edition;
    }

    struct PixelActivity {
        uint256 totalPixelPlaced;
        uint256 totalPixelAlive;
        uint256 totalEthPaid;
    }

    mapping(uint8 => mapping(uint256 => mapping(uint256 => Cell))) public boards;
    mapping(address => PixelActivity) public userActivity;
    mapping(string => bool) public validColors;

    bool public paused;
    uint256 public constant BASE_COST = 0.000022 ether;
    uint256 public constant COST_MULTIPLIER = 115; // 115% = 1.15x
    uint256 public constant COST_DIVISOR = 100;

    event PixelSet(
        uint8 boardId,
        uint256 x,
        uint256 y,
        string color,
        address owner,
        uint256 edition,
        uint256 totalPixelPlaced,
        uint256 totalPixelAlive,
        uint256 totalEthPaid
    );

    constructor() Ownable(msg.sender) {
        string[16] memory colors = [
            "white", "black", "gray", "silver", "maroon", "red", "purple", "fuscia",
            "green", "lime", "olive", "yellow", "navy", "blue", "teal", "aqua"
        ];
        for (uint i = 0; i < colors.length; i++) {
            validColors[colors[i]] = true;
        }
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    function setPixel(string memory encodedData) external payable whenNotPaused {
        (uint8 boardId, uint256 x, uint256 y, string memory color) = decodeSetPixelData(encodedData);
        require(boardId < 4, "Invalid boardId");
        require(validColors[color], "Invalid color");

        Cell storage cell = boards[boardId][x][y];
        uint256 cost = getPixelCost(boardId, x, y);
        require(msg.value >= cost, "Insufficient payment");

        if (cell.owner != address(0)) {
            userActivity[cell.owner].totalPixelAlive -= 1;
        }

        cell.owner = msg.sender;
        cell.color = color;
        cell.edition += 1;

        userActivity[msg.sender].totalPixelPlaced += 1;
        userActivity[msg.sender].totalPixelAlive += 1;
        userActivity[msg.sender].totalEthPaid += cost;

        emit PixelSet(boardId, x, y, color, msg.sender, cell.edition, 
                      userActivity[msg.sender].totalPixelPlaced, 
                      userActivity[msg.sender].totalPixelAlive, 
                      userActivity[msg.sender].totalEthPaid);

        if (msg.value > cost) {
            payable(msg.sender).transfer(msg.value - cost);
        }
    }

    function setPixels(uint8 boardId, uint256[] memory xList, uint256[] memory yList, string[] memory colorList) 
        external payable whenNotPaused {
        require(boardId < 4, "Invalid boardId");
        require(xList.length > 0 && yList.length > 0, "xList and yList must not be empty");
        require(colorList.length == xList.length * yList.length, "colorList length must be xList.length * yList.length");

        uint256 totalCost = 0;
        // Validate all colors and sum costs
        for (uint i = 0; i < xList.length; i++) {
            for (uint j = 0; j < yList.length; j++) {
                uint colorIdx = i * yList.length + j;
                require(validColors[colorList[colorIdx]], "Invalid color");
                totalCost += getPixelCost(boardId, xList[i], yList[j]);
            }
        }
        require(msg.value >= totalCost, "Insufficient payment");

        for (uint i = 0; i < xList.length; i++) {
            for (uint j = 0; j < yList.length; j++) {
                uint colorIdx = i * yList.length + j;
                Cell storage cell = boards[boardId][xList[i]][yList[j]];
                if (cell.owner != address(0)) {
                    userActivity[cell.owner].totalPixelAlive -= 1;
                }
                cell.owner = msg.sender;
                cell.color = colorList[colorIdx];
                cell.edition += 1;

                userActivity[msg.sender].totalPixelPlaced += 1;
                userActivity[msg.sender].totalPixelAlive += 1;
                userActivity[msg.sender].totalEthPaid += getPixelCost(boardId, xList[i], yList[j]);

                emit PixelSet(boardId, xList[i], yList[j], colorList[colorIdx], msg.sender, cell.edition, 
                              userActivity[msg.sender].totalPixelPlaced, 
                              userActivity[msg.sender].totalPixelAlive, 
                              userActivity[msg.sender].totalEthPaid);
            }
        }

        if (msg.value > totalCost) {
            payable(msg.sender).transfer(msg.value - totalCost);
        }
    }

    function getPixelCost(uint8 boardId, uint256 x, uint256 y) public view returns (uint256) {
        require(boardId < 4, "Invalid boardId");
        require(x < 170 && x >= 0, "Invalid x coordinate");
        require(y < 100 && y >= 0, "Invalid y coordinate");
        uint256 edition = boards[boardId][x][y].edition;
        return BASE_COST * (COST_MULTIPLIER ** edition) / (COST_DIVISOR ** edition);
    }

    function getPixelsCost(uint8 boardId, uint256[] memory xList, uint256[] memory yList)
        external view returns (uint256 totalCost)
    {
        require(boardId < 4, "Invalid boardId");
        require(xList.length > 0 && yList.length > 0, "xList and yList must not be empty");

        for (uint i = 0; i < xList.length; i++) {
            require(xList[i] < 170 && xList[i] >= 0, "Invalid x coordinate");
        }
        for (uint j = 0; j < yList.length; j++) {
            require(yList[j] < 100 && yList[i] >= 0, "Invalid y coordinate");
        }
        for (uint i = 0; i < xList.length; i++) {
            for (uint j = 0; j < yList.length; j++) {
                totalCost += getPixelCost(boardId, xList[i], yList[j]);
            }
        }
    }

    function retrieveEth(address payable recipient) external onlyOwner {
        recipient.transfer(address(this).balance);
    }

    function pause(bool _paused) external onlyOwner {
        paused = _paused;
    }

    function decodeSetPixelData(string memory encodedData) internal pure returns (uint8, uint256, uint256, string memory) {
        // Expects a comma-separated string: "boardId,x,y,color"
        bytes memory strBytes = bytes(encodedData);
        uint8 boardId;
        uint256 x;
        uint256 y;
        string memory color;

        uint idx = 0;
        uint start = 0;
        uint8 step = 0;
        bytes memory colorBytes;

        for (uint i = 0; i < strBytes.length; i++) {
            if (strBytes[i] == ",") {
                bytes memory part = new bytes(i - start);
                for (uint j = 0; j < i - start; j++) {
                    part[j] = strBytes[start + j];
                }
                if (step == 0) {
                    boardId = uint8(parseUint(string(part)));
                } else if (step == 1) {
                    x = parseUint(string(part));
                } else if (step == 2) {
                    y = parseUint(string(part));
                }
                start = i + 1;
                step++;
            }
        }
        // The last part is color
        colorBytes = new bytes(strBytes.length - start);
        for (uint j = 0; j < strBytes.length - start; j++) {
            colorBytes[j] = strBytes[start + j];
        }
        color = string(colorBytes);

        return (boardId, x, y, color);
    }

    function parseUint(string memory s) internal pure returns (uint256) {
        bytes memory b = bytes(s);
        uint256 result = 0;
        for (uint i = 0; i < b.length; i++) {
            require(b[i] >= 0x30 && b[i] <= 0x39, "Invalid uint string");
            result = result * 10 + (uint8(b[i]) - 48);
        }
        return result;
    }
}