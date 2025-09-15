pragma solidity ^0.8.0;

import {IRewardsController} from './IRewardsController.sol';

/**
 * @title IAToken
 * @author Aave
 * @notice Defines the basic interface for an AToken.
 **/
interface IAToken {
  
  /**
   * @dev Returns the address of the incentives controller contract
   **/
  function getIncentivesController() external view returns (IRewardsController);

}