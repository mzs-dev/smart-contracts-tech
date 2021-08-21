pragma solidity 0.7.0;

import "./IERC20.sol";
import "./IMintableToken.sol";
import "./IDividends.sol";
import "./SafeMath.sol";

contract Token is IERC20, IMintableToken, IDividends {
  // ------------------------------------------ //
  // ----- BEGIN: DO NOT EDIT THIS SECTION ---- //
  // ------------------------------------------ //
  using SafeMath for uint256;
  uint256 public totalSupply;
  uint256 public decimals = 18;
  string public name = "Test token";
  string public symbol = "TEST";
  mapping (address => uint256) public balanceOf;
  // ------------------------------------------ //
  // ----- END: DO NOT EDIT THIS SECTION ------ //  
  // ------------------------------------------ //

  // Custom struct to optimize token holder metadata storage
  struct Info{
    bool isTracked; // To check if the token holder is tracked for Dividends or not
    uint248 withdrawableDividends; // To store the cumulative accrued rewards
  }

  //Declaring a storage array to keep track of token holders
  address[] public tokenHolders;
  //Keeping it private as it need to be accessed externally

  //Declaring a storage mapping to keep track of accrued Dividends to toekn holders
  mapping (address => Info) private tokenHolderInfo; 
  // Delibaretly keeping it private as a required getter already exists "getWithdrawableDividend(address payee)"

  //Declaring another state variable to track allowances by Owner to Spender matching the standard ERC20 implementation
  mapping (address => mapping (address => uint256)) private allowances;

  //Modifier to track token holder addresses efficiently
  modifier trackReceiver(address receiver) {
    if(!tokenHolderInfo[receiver].isTracked){
      tokenHolderInfo[receiver].isTracked = true;
      tokenHolders.push(receiver);
    }
    _;
  }

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
  }

  //To be called by transfer and transferFrom functions
  function transferHelper(address from, address to, uint256 value) internal trackReceiver(to) {
    balanceOf[from] = balanceOf[from].sub(value, "transfer: value exceeds balance");
    balanceOf[to] = balanceOf[to].add(value);
  }

  // IMintableToken

  function mint() external payable trackReceiver(msg.sender) override {
    require(msg.value > 0, "mint: 0 value");
    balanceOf[msg.sender] = balanceOf[msg.sender].add(msg.value);
    totalSupply = totalSupply.add(msg.value);
  }

  function burn(address payable dest) external override {
    uint256 payableAmount = balanceOf[msg.sender];
    balanceOf[msg.sender] = 0; // * To prevent Reentrency *
    totalSupply = totalSupply.sub(payableAmount);
    dest.transfer(payableAmount);
  }

  // IDividends

  function recordDividend() external payable override {
    address[] memory _tokenHolders = tokenHolders; // copying the tokenHolders array to memory for later gas optimization
    require(_tokenHolders.length > 0 && msg.value > 0, "recordDividend: No token holders exists || 0 value");
    uint i;
    while(i < _tokenHolders.length){
      // Looping over the entire range of tracked token holders to distribute dividends
      tokenHolderInfo[_tokenHolders[i]].withdrawableDividends += uint248(((msg.value).mul(balanceOf[_tokenHolders[i]])).div(totalSupply));
      i++;
    }

  }

  function getWithdrawableDividend(address payee) external view override returns (uint256) {
    return tokenHolderInfo[payee].withdrawableDividends;
  }

  function withdrawDividend(address payable dest) external override {
    uint256 value = tokenHolderInfo[msg.sender].withdrawableDividends;
    require(value > 0, "withdrawDividend: No dividend accrued");
    tokenHolderInfo[msg.sender].withdrawableDividends = 0;
    dest.transfer(value);
  }
}