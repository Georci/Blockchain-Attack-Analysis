// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IOracle {
    function isRandomnessSet(uint256 requestId) external view returns (bool);

    function getRandomNumber(uint256 requestId) external view returns (uint256);

    function requestRandomness() external returns (uint256);
}
