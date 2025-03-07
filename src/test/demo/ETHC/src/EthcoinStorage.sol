// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./interfaces/IReverseRegistrar.sol";

contract EthcoinStorage {
    /// @notice The reverse registrar
    address public reverseRegistrar;

    /// @notice The flag to check if the mining is started
    bool public isStarted;

    /// @notice The cost to mine
    uint256 public mineCost;

    /// @notice The mining reward
    uint256 public miningReward;

    /// @notice The current block number
    uint256 public blockNumber;

    /// @notice The last block time
    uint256 public lastBlockTime;

    /// @notice The halving interval
    uint256 public halvingInterval;

    /// @notice The last halving block
    uint256 public lastHalvingBlock;

    /// @notice The fee collector address
    address public feeCollector;

    struct Block {
        address[] miners;
        address selectedMiner;
        uint256 miningReward;
    }

    /// @notice The blocks data
    mapping(uint256 => Block) public blocks;

    /// @notice The block number to request ID mapping
    mapping(uint256 => uint256) public blockNumberToRequests;

    /// @notice The randomness oracle
    address public oracle;

    /// @notice The request ID to block number mapping
    mapping(uint256 => uint256) public requestsToBlockNumber;
}
