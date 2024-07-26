// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {Errors} from "./interface/Errors.sol";

contract MooreResult is Errors {
    function calculateMooreResult(
        bytes calldata returnData
    ) public pure returns (uint[] memory) {
        uint[] memory candidateList = abi.decode(returnData, (uint[]));
        uint candidatesLength = candidateList.length;

        if (candidatesLength == 0) {
            revert NoWinner();
        }
        if (candidatesLength == 1) {
            uint[] memory singleWinner = new uint[](1);
            singleWinner[0] = 0;
            return singleWinner;
        }

        uint maxVotes = 0;
        uint winnerCount = 0;
        uint[] memory winners;
        for (uint i = 0; i < candidatesLength; i++) {
            uint votes = candidateList[i];
            if (votes > candidatesLength / 2) {
                winners = new uint[](1);
                winners[0] = i;
                return winners;
            } else if (votes > maxVotes) {
                maxVotes = votes;
                winnerCount = 1;
            } else if (votes == maxVotes) {
                winnerCount++;
            }
        }

        winners = new uint[](winnerCount);
        uint numWinners = 0;

        for (uint i = 0; i < candidatesLength; i++) {
            if (candidateList[i] == maxVotes) {
                winners[numWinners] = i;
                numWinners++;
            }
        }

        return winners;
    }
}
