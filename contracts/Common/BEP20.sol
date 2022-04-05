// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract BEP20 is ERC20, Ownable {
    function getOwner() external view returns (address){
        return owner();
    }
}