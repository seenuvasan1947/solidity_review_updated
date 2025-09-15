// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract SimplePoll {
    struct Option {
        string name;
        uint256 voteCount;
    }

    Option[] public options;
    mapping(address => bool) public hasVoted;

    constructor(string[] memory _options) {
        for (uint i = 0; i < _options.length; i++) {
            options.push(Option({name: _options[i], voteCount: 0}));
        }
    }

    function vote(uint optionIndex) public {
        require(!hasVoted[msg.sender], "Already voted");
        require(optionIndex < options.length, "Invalid option");

        options[optionIndex].voteCount += 1;
        hasVoted[msg.sender] = true;
    }

    function getOptions() public view returns (Option[] memory) {
        return options;
    }
}
