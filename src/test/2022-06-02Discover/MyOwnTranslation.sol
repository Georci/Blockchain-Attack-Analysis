pragma solidity ^0.8.15;

contract Translation {
    address public ETHpledge = 0xe732a7bD6706CBD6834B300D7c56a8D2096723A7;
    IERC20 discover = IERC20(0x5908E4650bA07a9cf9ef9FD55854D4e1b700A267);
    IERC20 bsc_usd = IERC20(0x55d398326f99059fF775485246999027B3197955);

    function _transfer(address Varg) public returns (bool){
        uint256 DiscoverBalnace = discover.balanceOf(address(this));
        bool success = discover.transfer(Varg, DiscoverBalnace);
        require(success, "Transfer failed");
        return true;
    }

    function invest() public {
        bsc_usd.approve(ETHpledge, 115792089237316195423570985008687907853269984665640564039457584007913129639935);
        bytes memory data = abi.encodeWithSignature("pledgein(address,uint256)", 0x0000000000000000000000000000000000000000,1000000000000000000);
        (bool success, ) = ETHpledge.call(data);
        if(!success){revert("Called ETHpledge failed");}
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);
}
