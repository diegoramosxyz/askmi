//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

// import Foo.sol from current directory
import "./askmi.sol";

contract AskMiFactory {
    address[] internal askMis;
    mapping(address => uint256) internal askMisIndexedByOwner;
    address internal owner;

    event AskMiInstantiated(address _askMiAddress);

    constructor() {
        owner = msg.sender;
        // Ocuppy the first element to easily perform lookups
        askMis.push(address(0));
    }

    // Get the address of the contract corresponding to the owner
    function getMyAskMi(address _owner) public view returns (address) {
        uint256 askMiIndex = askMisIndexedByOwner[_owner];
        require(
            // askMisIndexedByOwner will return 0 as a default value
            askMiIndex > 0,
            "The selected address has not created an AskMi contract."
        );
        return askMis[askMiIndex];
    }

    function instantiateAskMi(uint256[] memory _tiers, uint256 _tip)
        public
        returns (address)
    {
        // Check that the tiers array is not empty
        require(_tiers.length > 0, "Please, include at least one tier.");

        // Only allow one AskMi instance per address
        require(
            askMisIndexedByOwner[msg.sender] == 0,
            "This address already owns an AskMi instance."
        );

        AskMi _askMi = new AskMi(msg.sender, _tiers, _tip, owner);
        askMisIndexedByOwner[msg.sender] = askMis.length;
        askMis.push(address(_askMi));
        emit AskMiInstantiated(address(_askMi));
        return address(_askMi);
    }
}
