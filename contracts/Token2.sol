pragma solidity 0.7.0;

import "./IERC20.sol";
import "./IMintableToken.sol";
import "./IDividends.sol";
import "./SafeMath.sol";

contract Token2 is IERC20, IMintableToken, IDividends {
  using SafeMath for uint256;
  uint256 public totalSupply;
  uint256 public decimals = 18;
  string public name = "Test token";
  string public symbol = "TEST";
  
  // Custom struct to optimize token holder metadata storage
  struct Info{
    uint256 balance; // To store balance of token 
    uint256 withdrawableDividends; // To store the cumulative accrued rewards
    uint256 dividendDebt; // variable for linear regression maths to compute actual dividends applicable 
  }

  uint256 dividendPerToken; // storgae variable to track cumulative accrued dividend per token 

  //Declaring a storage array to keep track of token holders
//   address[] public tokenHolders;
  //Keeping it private as it need to be accessed externally

  //Declaring a storage mapping to keep track of accrued Dividends to toekn holders
  mapping (address => Info) private tokenHolderInfo; 
  // Delibaretly keeping it private as a required getter already exists "getWithdrawableDividend(address payee)"

  //Declaring another state variable to track allowances by Owner to Spender matching the standard ERC20 implementation
  mapping (address => mapping (address => uint256)) private allowances;

  //Modifier to track token holder addresses efficiently
//   modifier trackReceiver(address receiver) {
//     if(!tokenHolderInfo[receiver].isTracked){
//       tokenHolderInfo[receiver].isTracked = true;
//       tokenHolders.push(receiver);
//     }
//     _;
//   }

  // IERC20


  function allowance(address owner, address spender) external view override returns (uint256) {
    return allowances[owner][spender];
  }

  function transfer(address to, uint256 value) external override returns (bool) {
    transferHelper(msg.sender, to, value);
    return true;
  }

  function approve(address spender, uint256 value) external override returns (bool) {
    allowances[msg.sender][spender] = value; 
    return true;
  }

  function transferFrom(address from, address to, uint256 value) external override returns (bool) {
    allowances[from][msg.sender] = allowances[from][msg.sender].sub(value, "transferFrom: value exceeds allowance");
    transferHelper(from, to, value);
    return true;
  }

  // Custom: To be called by transfer and transferFrom functions
  function transferHelper(address from, address to, uint256 value) internal {
    Info memory memI = tokenHolderInfo[from];
    uint256 newBalance = memI.balance.sub(value, "transfer: value exceeds balance");
    tokenHolderInfo[from] = Info(newBalance, dividendHelper(memI), cumulativeDividend(newBalance));
    memI = tokenHolderInfo[to];
    newBalance = memI.balance.add(value);
    tokenHolderInfo[to] = Info(newBalance, dividendHelper(memI), cumulativeDividend(newBalance));
  }

  // Custom: To maintain the balance format to query balance of token holder
  function balanceOf(address holder) external view returns (uint256){
    return tokenHolderInfo[holder].balance;      
  }

  // IMintableToken

  function mint() external payable override {
    require(msg.value > 0, "mint: 0 value");
    Info memory memI = tokenHolderInfo[msg.sender];
    uint newBalance = memI.balance.add(msg.value);
    tokenHolderInfo[msg.sender] = Info(newBalance, dividendHelper(memI), cumulativeDividend(newBalance));
    totalSupply = totalSupply.add(msg.value);
  }

  function burn(address payable dest) external override {
    Info memory memI = tokenHolderInfo[msg.sender];
    tokenHolderInfo[msg.sender] = Info(0, dividendHelper(memI), 0) ; // * To prevent Reentrency *
    totalSupply = totalSupply.sub(memI.balance);

    dest.transfer(memI.balance);
  }

  // IDividends

  function recordDividend() external payable override {
    uint _totalSupply = totalSupply;
    require(_totalSupply > 0 && msg.value > 0, "recordDividend: No token holders exists || 0 value");
    dividendPerToken += msg.value.mul(1e18).div(_totalSupply);
  }

  function getWithdrawableDividend(address payee) external view override returns (uint256) {
    Info memory memI = tokenHolderInfo[payee];
    return dividendHelper(memI);
  }

  function withdrawDividend(address payable dest) external override {
    Info memory memI = tokenHolderInfo[msg.sender];
    uint value = dividendHelper(memI);
    require(value > 0, "withdrawDividend: No dividend accrued");
    (tokenHolderInfo[msg.sender].withdrawableDividends, tokenHolderInfo[msg.sender].dividendDebt)  = (0, cumulativeDividend(memI.balance));
    dest.transfer(value);
  }

  function cumulativeDividend(uint256 forBalance) internal view returns(uint256) {
    return forBalance.mul(dividendPerToken).div(1e18);
  }

  function dividendHelper(Info memory memI) internal view returns(uint256) {
    return (memI.withdrawableDividends).add(cumulativeDividend(memI.balance).sub(memI.dividendDebt));
  }


}