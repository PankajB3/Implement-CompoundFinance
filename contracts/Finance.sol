// SPDX-License-Identifier:MIT

pragma solidity >=0.8.0;

// import "./CErc20.sol";
import "./BAT.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ICERC20 {
    function mint(uint256 mintAmount) external returns (uint256);

    function exchangeRateCurrent() external returns (uint256);

    function supplyRatePerBlock() external returns (uint256);

    function redeem(uint256) external returns (uint256);

    function redeemUnderlying(uint256) external returns (uint256);

    function borrow(uint borrowAmount) external returns (uint);

    function borrowRatePerBlock() external view returns (uint256);

    function borrowBalanceCurrent(address) external returns (uint256);

    function repayBorrow(uint256) external returns (uint256);
}

interface Comptroller {
    function markets(address) external returns (bool, uint256);

    function enterMarkets(address[] calldata)
        external
        returns (uint256[] memory);

    function getAccountLiquidity(address)
        external
        view
        returns (uint256, uint256, uint256);
}

interface PriceFeed {
    function getUnderlyingPrice(address cToken) external view returns (uint);
}

interface CEth {
    function mint() external payable;

    function borrow(uint256) external returns (uint256);

    function repayBorrow() external payable;

    function borrowBalanceCurrent(address) external returns (uint256);
}

contract MyFinance {
    // cEth Rinkweby 0xd6801a1dffcd0a410336ef88def4320d6df1883e
    // comptroller Rinkeby 0x2eaa9d77ae4d8f9cdd9faacd44016e746485bddb
    address payable private  cETHAddr;
    address private comptroller;
    address private cDaiAddr = 0x6D7F0754FFeb405d23C51CE938289d4835bE3b14;
    address private daiAddr;
    // 0x5592EC0cfb4dbc12D3aB100b257153436a1f0FEa
    address private cERC20;
    // 0x6D7F0754FFeb405d23C51CE938289d4835bE3b14
    constructor(address _dai, address _cErc, address payable _cETH, address _comptroller) {
        daiAddr = _dai;
        cERC20 = _cErc;
        cETHAddr = _cETH;
        comptroller = _comptroller;
    }

    function mint(uint256 amt) external returns(uint256){
        
        // IERC20(daiAddr).transferFrom(msg.sender,address(this),amt);
        IERC20(daiAddr).approve(cERC20,amt);
        uint256 res = ICERC20(cERC20).mint(amt);
        return res;
    }

    function redeemMySupply(address _cErc20, bool flag, uint256 amt) external returns(uint256){
        // if flag  = true
            // redeem based on Ctoken
        // else
            // redeem based on supply asset value
        uint256 redeemAmt;
        if(flag){
            // The redeem function converts a specified quantity of cTokens into the underlying asset, and returns them to the user
           redeemAmt =  ICERC20(_cErc20).redeem(amt);
        }else{
            // The redeem underlying function converts cTokens into a specified quantity of the underlying asset
           redeemAmt =  ICERC20(_cErc20).redeemUnderlying(amt);
        }
        return redeemAmt;
    }

    // function getSupplyRate() external returns(uint256){
    //     // Amount added to you supply balance this block
    //     uint256 supplyRateMantissa = ICERC20(cERC20).supplyRatePerBlock();
    //     return supplyRateMantissa;
    // }

    // function getCurrentExchangeRate() external returns(uint256){
    //     // Amount of current exchange rate from cToken to underlying
    //     uint256 exchangeRateMantissa = ICERC20(cERC20).exchangeRateCurrent();
    //     return exchangeRateMantissa;
    // }

    // function getCERCBalance() external view returns(uint256){
    //     // return address(this).balance;
    //     return ICERC20().balanceOf();
    // }

    // function getCERCBalance() external view returns(uint256){
    //     // return address(this).balance;
    //     return IERC20(cERC20).balanceOf(address(this));
    // }

    function getDAIBalance() external view returns(uint256){
        return IERC20(daiAddr).balanceOf(address(this));
    }

    function getcDAIBalance() external view returns(uint256){
        return IERC20(cDaiAddr).balanceOf(address(this));
    }

    // BORROW FUNCTIONS

    function borrowETH(uint256 amt) external returns(uint256){
        // 1. after providing dai , & getting cDai
        // 2. we need to enter MArket, to tell compound that I need to borrow
        address[] memory cTokenArr = new address[](1);
        cTokenArr[0] = cERC20;
        uint256[] memory errCodeArr =  Comptroller(comptroller).enterMarkets(cTokenArr);
        // if 0 is not returned that means transaction fails.....
        require(errCodeArr[0]==0,"Failed To Enter The Market");

        // Account Liquidity represents the USD value borrowable by a user, before it reaches liquidation.
        (uint256 err,uint256 liquidity,uint256 shortFall) = Comptroller(comptroller).getAccountLiquidity(address(this));

        require(err==0,"Error occured in getting liquidity");
        require(shortFall == 0, "account underwater");
        require(liquidity > 0, "account has excess collateral");

        // get maximum amount which can be borrowed, comptroller.markets
        (bool isListed, uint256 collateralFactorMantissa) = Comptroller(comptroller).markets(cERC20);
        require(isListed,"comptroller does not recognizes this cToken");
        // require(isComped,"Not a COMP token");
        require(amt<collateralFactorMantissa,"Amount borrowed should be less");

        CEth(cETHAddr).borrow(amt);

        uint256 borrows = CEth(cETHAddr).borrowBalanceCurrent(address(this));

        return borrows;
    }

    function checkBorrowedETHBalance() external view returns(uint256){
        // this works only for ether balance.
        return address(this).balance;
    }

    // function borrowBalance() external returns(uint256){
    //     uint256 borrows = CEth(cETHAddr).borrowBalanceCurrent(address(this));
    //     return borrows;
    // }

     receive() external payable {}

// REPAY BORROWED ETH
     function repayEth(uint256 repayAmt) payable external{
//          msg.value payable: The amount of ether to be repaid, in wei.
// msg.sender: The account which borrowed the asset, and shall repay the borrow.
// RETURN: No return, reverts on error.
         CEth(cETHAddr).repayBorrow{value:repayAmt}();
     }

}
