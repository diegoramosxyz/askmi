//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./askmi-erc20.sol";

// @title A factory for AskMi contracts
// @author Diego Ramos
contract AskMiFactory_ERC20 {
    // @notice The selected ERC20 to act as currency
    IERC20 public token;

    // @notice Array containing all AskMi instances
    address[] internal askMis;

    // @notice Index to query the askMis array by the owner's address
    mapping(address => uint256) internal askMisIndexedByOwner;

    // @notice owner of the current AskMi factory
    address internal owner;

    // Record the instantiation of an AskMi contract
    event AskMiInstantiated(address _askMiAddress);

    constructor(address _token) {
        token = IERC20(_token);
        owner = msg.sender;
        // Ocuppy the first element to easily perform lookups
        askMis.push(address(0));
    }

    // @notice Get someone's AskMi instance
    function getMyAskMi(address _owner) public view returns (address) {
        uint256 askMiIndex = askMisIndexedByOwner[_owner];
        require(
            // askMisIndexedByOwner will return 0 as a default value
            askMiIndex > 0,
            "The selected address has not created an AskMi contract."
        );
        return askMis[askMiIndex];
    }

    function instantiateAskMi(uint256[] memory _tiers, uint256 _tip) public {
        // Only allow one AskMi instance per address
        require(
            askMisIndexedByOwner[msg.sender] == 0,
            "This address already owns an AskMi instance."
        );

        uint256 _tiersSize = _tiers.length;
        uint256 _supply = token.totalSupply();

        // Check that the tiers array is not empty and not bigger than 3
        require(
            _tiersSize > 0 && _tiersSize <= 3,
            "There must be between 1 and 3 tiers."
        );

        // Check that tiers do not exceed total supply
        for (uint256 i = 0; i < _tiersSize; i++) {
            require(
                _tiers[i] <= _supply,
                "At least one of the tiers has a value greater than the token's total supply."
            );
        }

        // Instantiate AskMi contract
        AskMi_ERC20 _askMi = new AskMi_ERC20(
            address(token),
            msg.sender,
            _tiers,
            _tip,
            owner
        );

        // Save the owner's index
        askMisIndexedByOwner[msg.sender] = askMis.length;

        // Save the address of the new AskMi
        askMis.push(address(_askMi));

        emit AskMiInstantiated(address(_askMi));
    }
}
