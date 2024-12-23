// SPDX-License-Identifier: MIT
// pragma solidity 0.8.20;

// import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

// contract EthPrice{

//     AggregatorV3Interface internal dataFeed;

//     constructor(){
//         dataFeed = AggregatorV3Interface(0x5fb1616F78dA7aFC9FF79e0371741a747D2a7F22);
//     }

//      function getChainlinkDataFeedLatestAnswer() public view returns (int) {

//         (,int answer,,,) = dataFeed.latestRoundData();
//         return answer;
//     }


// }


pragma solidity ^0.8.0;
// import "hardhat/console.sol";

contract Unpredictable {
    function getPseudoRandomNumber() public view returns (uint256) {
        // Combine block properties to generate a pseudo-random number

        
        // uint hell =uint256(keccak256(abi.encodePacked(
        //     block.difficulty, 
        //     block.timestamp,
        //     block.number,
        //     blockhash(block.number - 1)
        // )));
        // console.log(hell);
        return  uint256(keccak256(abi.encodePacked(
            block.difficulty, 
            block.timestamp,
            block.number,
            blockhash(block.number - 1)
        )));
    }
}
