// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IBallot} from "./ballots/interface/IBallot.sol";
import {IResultCalculator} from "./resultCalculators/interface/IResultCalculator.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract Election is Initializable {
    error OwnerPermissioned();
    error AlreadyVoted();
    error GetVotes();
    error ElectionIncomplete();
    error ElectionInactive();
    error InvalidCandidateID();
    string private constant DEFAULT_IPFS_HASH = "QmDefaultIpfsHash";

    mapping(address user => bool isVoted) public userVoted;

    struct ElectionInfo {
        uint startTime;
        uint endTime;
        string name;
        string description;
        // Election type: 0 for invite based 1 for open
    }

    struct Candidate {
        uint candidateID; // remove candidateId its not needed
        string name;
        string description;
        string ipfsHash;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert OwnerPermissioned();
        _;
    }

    modifier electionInactive() {
        if (
            block.timestamp < electionInfo.startTime ||
            block.timestamp > electionInfo.endTime
        ) revert ElectionInactive();
        _;
    }

    modifier electionStarted() {
        if (block.timestamp > electionInfo.startTime) revert ElectionInactive();
        _;
    }

    ElectionInfo public electionInfo;

    address public factoryContract;
    address public owner;

    uint[] public winners;
    uint public electionId;
    uint public resultType;
    uint public totalVotes;
    bool public resultsDeclared;

    bool private ballotInitialized;

    IBallot private ballot;
    IResultCalculator private resultCalculator;

    Candidate[] public candidates;

    function initialize(
        ElectionInfo memory _electionInfo,
        Candidate[] memory _candidates,
        uint _resultType,
        uint _electionId,
        address _ballot,
        address _owner,
        address _resultCalculator
    ) external initializer {
        electionInfo = _electionInfo;
        for(uint i = 0; i < _candidates.length; i++) {
            // Check for empty IPFS hash and use default
            string memory ipfsHash = bytes(_candidates[i].ipfsHash).length > 0 
                ? _candidates[i].ipfsHash 
                : DEFAULT_IPFS_HASH;
            
            candidates.push(
                Candidate(
                    i,
                    _candidates[i].name,
                    _candidates[i].description,
                    ipfsHash  // Use processed hash
                )
            );
        }

        resultType = _resultType;
        electionId = _electionId;
        owner = _owner;
        factoryContract = msg.sender;
        ballot = IBallot(_ballot);
        resultCalculator = IResultCalculator(_resultCalculator);
    }

    function userVote(uint[] memory voteArr) external electionInactive {
        if (userVoted[msg.sender]) revert AlreadyVoted();
        if (ballotInitialized == false) {
            ballot.init(candidates.length);
            ballotInitialized = true;
        }
        ballot.vote(voteArr);
        userVoted[msg.sender] = true;
        totalVotes++;
    }

    function ccipVote(
        address user,
        uint[] memory _voteArr
    ) external electionInactive {
        if (userVoted[user]) revert AlreadyVoted();
        if (ballotInitialized == false) {
            ballot.init(candidates.length);
            ballotInitialized = true;
        }
        if (msg.sender != factoryContract) revert OwnerPermissioned();
        userVoted[user] = true;
        ballot.vote(_voteArr);
        totalVotes++;
    }

    function addCandidate(
        string calldata _name,
        string calldata _description,
        string calldata _ipfsHash
    ) external onlyOwner electionStarted {
        // Use default if empty (already implemented)
        string memory ipfsHash = bytes(_ipfsHash).length > 0 
            ? _ipfsHash 
            : DEFAULT_IPFS_HASH;
        
        Candidate memory newCandidate = Candidate(
            candidates.length,
            _name,
            _description,
            ipfsHash
        );
        candidates.push(newCandidate);
    }

    function removeCandidate(uint _id) external onlyOwner electionStarted {
        if (_id >= candidates.length) revert InvalidCandidateID();
        candidates[_id] = candidates[candidates.length - 1]; // Replace with last element
        candidates.pop(); 
    }

    function getCandidateList() external view returns (Candidate[] memory) {
        return candidates;
    }

    function getResult() external {
        if (block.timestamp < electionInfo.endTime) revert ElectionIncomplete();
        bytes memory payload = abi.encodeWithSignature("getVotes()");

        (bool success, bytes memory allVotes) = address(ballot).staticcall(
            payload
        );
        if (!success) revert GetVotes();

        uint[] memory _winners = resultCalculator.getResults(
            allVotes,
            resultType
        );
        winners = _winners;
        resultsDeclared = true;
    }

    function getWinners() external view returns (uint[] memory) {
        return winners;
    }
}
