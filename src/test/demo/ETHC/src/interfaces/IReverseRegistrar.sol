// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IReverseRegistrar {
    function setName(string memory name) external returns (bytes32);
}
