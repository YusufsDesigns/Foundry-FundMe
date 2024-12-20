// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { PriceConverter } from "./PriceConverter.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

error FundMe_NotOwner();
error FundMe_NotEnouphEth();

contract FundMe {
    using PriceConverter for uint256;

    uint256 public constant MINIMUM_USD = 5e18;
    address private immutable i_owner;
    AggregatorV3Interface private s_priceFeed;

    constructor(address priceFeed){
        i_owner = msg.sender;
        s_priceFeed = AggregatorV3Interface(priceFeed);
    }

    address[] private s_funders;
    mapping (address funder => uint256 amountFunded) private s_addressToAmountFunded;
    
    function fund() public payable  {
        if(msg.value.getConversionRate(s_priceFeed) <= MINIMUM_USD){
            revert FundMe_NotEnouphEth();
        }
        s_funders.push(msg.sender);
        s_addressToAmountFunded[msg.sender] += msg.value;
    }

    function cheaperWithdraw() public onlyOwner {
        uint256 fundersLength = s_funders.length;
        for(uint256 funderIndex = 0; funderIndex < fundersLength; funderIndex++){
            address funder = s_funders[funderIndex];
            s_addressToAmountFunded[funder] = 0;
        }
        s_funders = new address[](0);
        (bool callSuccess, ) = payable(msg.sender).call{value: address(this).balance}("");
        if(!callSuccess){
            revert FundMe_NotOwner();
        }
        require(callSuccess, "Withdrawal Failed");
    }

    function withdraw() public onlyOwner {
        for(uint256 funderIndex = 0; funderIndex < s_funders.length; funderIndex++){
            address funder = s_funders[funderIndex];
            s_addressToAmountFunded[funder] = 0;
        }
        s_funders = new address[](0);
        (bool callSuccess, ) = payable(msg.sender).call{value: address(this).balance}("");
        if(!callSuccess){
            revert FundMe_NotOwner();
        }
        require(callSuccess, "Withdrawal Failed");
    }

    function getVersion() public view returns (uint256) {
        return s_priceFeed.version();
    }

    modifier onlyOwner() {
        if(msg.sender != i_owner){
            revert FundMe_NotOwner();
        }
        require(msg.sender == i_owner, "Only owner of contract can withdraw");
        _;
    }

    receive() external payable { 
        fund();
    }

    fallback() external payable {
        fund();
    }

    /**
     * View / Pure functions (Getters)
     */

    function getAddressToAmountFunded(address fundingAddress) public view returns (uint256){
        return s_addressToAmountFunded[fundingAddress];
    }

    function getFunder(uint256 index) public view returns (address){
        return s_funders[index];
    }

    function getOwner() public view returns (address) {
        return i_owner;
    }
}