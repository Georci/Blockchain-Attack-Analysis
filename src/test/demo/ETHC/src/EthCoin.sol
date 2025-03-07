// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "../lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "../lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "../lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import "./interfaces/IReverseRegistrar.sol";
import "./interfaces/IOracle.sol";
import "./EthcoinStorage.sol";

contract Ethcoin is Initializable, ERC20Upgradeable, OwnableUpgradeable, UUPSUpgradeable, EthcoinStorage {
    /// @notice Maximum supply of the token
    uint256 public constant MAX_SUPPLY = 21000000e18; // 21 million

    /// @notice Block interval for mining
    uint256 public constant BLOCK_INTERVAL = 1 minutes;

    event Mine(uint256 indexed blockNumber, address indexed miner, uint256 mineCount);
    event NewETHCBlock(uint256 indexed blockNumber);
    event MinerSelected(uint256 blockNumber, address selectedMiner, uint256 miningReward);
    event FeeCollectorSet(address feeCollector);
    event MineCostSet(uint256 mineCost);
    event OracleSet(address oracle);

    modifier whenStarted() {
        require(isStarted, "not started");
        _;
    }

    /**
     * @notice Initializes the contract.
     * @param _reverseRegistrar The reverse registrar
     */
    function initialize(address _reverseRegistrar) public initializer {
        __ERC20_init("Ethcoin", "ETHC");
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();

        reverseRegistrar = _reverseRegistrar;

        mineCost = 0.0002 ether;
        miningReward = 200e18; // 200 ETHC
        halvingInterval = 10080; // 10080 Ethcoin blocks, ~1 week

        // Block number starts from 6633.
        blockNumber = 6632;
        _mint(msg.sender, 6633 * 200e18);
    }

    /**
     * @notice Get the miners for a specific block.
     * @param _blockNumber The block number
     * @return The miners
     */
    function minersOfBlock(uint256 _blockNumber) public view returns (address[] memory) {
        return blocks[_blockNumber].miners;
    }

    /**
     * @notice Get the miners for a specific block with a range.
     * @dev This function is not recommended to use for on-chain purposes.
     * @param _blockNumber The block number
     * @param _from The start index
     * @param _to The end index
     * @return The miners
     */
    function minersOfBlockWithRange(uint256 _blockNumber, uint256 _from, uint256 _to)
        public
        view
        returns (address[] memory)
    {
        uint256 count = _to - _from;
        address[] memory miners = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            miners[i] = blocks[_blockNumber].miners[_from + i];
        }
        return miners;
    }

    /**
     * @notice Get the number of miners for a specific block.
     * @param _blockNumber The block number
     * @return The number of miners
     */
    function minersOfBlockCount(uint256 _blockNumber) public view returns (uint256) {
        return blocks[_blockNumber].miners.length;
    }

    /**
     * @notice Get the selected miner for a specific block.
     * @param _blockNumber The block number
     * @return The selected miner
     */
    function selectedMinerOfBlock(uint256 _blockNumber) public view returns (address) {
        return blocks[_blockNumber].selectedMiner;
    }

    /**
     * @notice Get the next halving block.
     * @return The next halving block
     */
    function nextHalvingBlock() public view returns (uint256) {
        return lastHalvingBlock + halvingInterval;
    }

    /**
     * @notice Get the request ID for the target block.
     * @param _blockNumber The target block number
     * @return The request ID
     */
    function getRequestIdByBlockNumber(uint256 _blockNumber) public view returns (uint256) {
        return blockNumberToRequests[_blockNumber];
    }

    /**
     * @notice Get the block number for the request ID.
     * @param _requestId The request ID
     * @return The block number
     */
    function getBlockNumberByRequestId(uint256 _requestId) public view returns (uint256) {
        return requestsToBlockNumber[_requestId];
    }

    /**
     * @notice Mines the reward multiple times in the current block.
     * @param mineCount The number of times to mine
     */
    function mine(uint256 mineCount) public payable whenStarted {
        require(mineCount > 0, "invalid mine count");
        require(msg.value == mineCost * mineCount, "insufficient mine cost");

        _mine(msg.sender, blockNumber + 1, mineCount);

        _concludeBlock();
    }

    /**
     * @notice Mines the reward multiple times in the future block.
     * @param mineCount The number of times to mine per block
     * @param blockCount The number of future blocks to mine
     */
    function futureMine(uint256 mineCount, uint256 blockCount) public payable whenStarted {
        require(mineCount > 0 && blockCount > 0, "invalid mine count or block count");
        require(msg.value == mineCost * mineCount * blockCount, "insufficient mine cost");

        uint256 targetBlock = blockNumber + 1;
        for (uint256 i = 0; i < blockCount;) {
            _mine(msg.sender, targetBlock + i, mineCount);

            unchecked {
                i++;
            }
        }

        _concludeBlock();
    }

    /**
     * @notice Starts the mining.
     */
    function start() public onlyOwner {
        require(!isStarted, "already initialized");

        isStarted = true;
        lastBlockTime = block.timestamp;
    }

    /**
     * @notice Sets the fee collector address.
     * @param _feeCollector The fee collector address
     */
    function setFeeCollector(address _feeCollector) public onlyOwner {
        feeCollector = _feeCollector;

        emit FeeCollectorSet(_feeCollector);
    }

    /**
     * @notice Adjusts the mine cost.
     * @param _mineCost The mine cost
     */
    function adjustMineCost(uint256 _mineCost) public onlyOwner {
        mineCost = _mineCost;

        emit MineCostSet(_mineCost);
    }

    /**
     * @notice Sets the oracle.
     * @param _oracle The oracle
     */
    function setOracle(address _oracle) public onlyOwner {
        oracle = _oracle;

        emit OracleSet(_oracle);
    }

    /**
     * @notice Sets the ENS name.
     * @param name The name
     * @return The ENS node
     */
    function setName(string memory name) public onlyOwner returns (bytes32) {
        return IReverseRegistrar(reverseRegistrar).setName(name);
    }

    /**
     * @notice Collects the Ether.
     * @param amount The amount of Ether to collect
     */
    function collect(uint256 amount) public {
        require(msg.sender == feeCollector, "only feeCollector can collect");

        (bool sent,) = feeCollector.call{value: amount}("");
        require(sent, "failed to send Ether");
    }

    /**
     * @notice Oracle fullfills the randomness and selects the miner.
     * @param requestId The request ID
     * @param randomNumber The random number
     */
    function fulfillRandomness(uint256 requestId, uint256 randomNumber) public {
        require(msg.sender == address(oracle), "only oracle can select miner");

        uint256 targetBlock = requestsToBlockNumber[requestId];
        Block storage blockData = blocks[targetBlock];

        // Skip if the selected miner is already set.
        if (blockData.selectedMiner != address(0)) {
            return;
        }

        uint256 minerCount = minersOfBlockCount(targetBlock);
        if (minerCount == 0) {
            return;
        }
        uint256 randIdx = randomNumber % minerCount;
        address selectedMiner = blockData.miners[randIdx];

        // Mint the mining reward.
        if (totalSupply() + blockData.miningReward <= MAX_SUPPLY) {
            _mint(selectedMiner, blockData.miningReward);
        }

        // Record the selected miner.
        blockData.selectedMiner = selectedMiner;

        emit MinerSelected(targetBlock, selectedMiner, blockData.miningReward);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /**
     * @dev Concludes the block.
     */
    function _concludeBlock() private {
        if (block.timestamp >= lastBlockTime + BLOCK_INTERVAL) {
            // Proceed to the next block.
            blockNumber++;
            lastBlockTime = block.timestamp;

            // Resuest the randomness from ChainLink VRF.
            uint256 requestId = IOracle(oracle).requestRandomness();

            // Check if it's time for halving.
            if (blockNumber >= nextHalvingBlock()) {
                miningReward = miningReward / 2;
                halvingInterval = halvingInterval * 2;

                lastHalvingBlock = blockNumber;
            }

            blockNumberToRequests[blockNumber] = requestId;
            requestsToBlockNumber[requestId] = blockNumber;
            blocks[blockNumber].miningReward = miningReward;

            emit NewETHCBlock(blockNumber);
        }
    }

    /**
     * @dev Mines the reward.
     * @param user The user address
     * @param targetBlock The target block number to mine
     */
    function _mine(address user, uint256 targetBlock, uint256 counts) private {
        for (uint256 i = 0; i < counts;) {
            blocks[targetBlock].miners.push(user);

            unchecked {
                i++;
            }
        }

        emit Mine(targetBlock, user, counts);
    }
}
