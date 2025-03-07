pragma solidity ^0.8.0;
import "forge-std/Test.sol";
// import "./../interface.sol";
import "./ETHC/src/EthCoin.sol";

contract ETHC is Test {
    // address ethcoin = 0x4Ea973c18204e847769390626A68e2B2304Ca3b0;
    address proxy_ethcoin = 0xE957ea0b072910f508dD2009F4acB7238C308E29;
    Ethcoin ethcoin = Ethcoin(0x4Ea973c18204e847769390626A68e2B2304Ca3b0);

    address user = vm.addr(1);

    function setUp() public {
        vm.createSelectFork("mainnet", 21121623);
        vm.deal(user, 10 ether);
    }

    function test_startMine() public {
        bytes memory call_data = abi.encodeWithSignature("mine(uint256)", 30);
        uint value = 30 * 5e14;
        (bool success, ) = proxy_ethcoin.call{value: value}(call_data);

        // uint256 blocknumber = 
    }
}
