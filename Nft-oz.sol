// SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;

// import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";

// contract MyNFT is ERC721URIStorage, Ownable {
//     uint256 private _tokenIdCounter;

//     constructor() ERC721("CArs ", "SPCRS") Ownable(msg.sender) {}

//     function mintNFT(address recipient, string memory tokenURI) public onlyOwner returns (uint256) {
//         uint256 newItemId = _tokenIdCounter;
//         _safeMint(recipient, newItemId);
//         _setTokenURI(newItemId, tokenURI);
//         _tokenIdCounter += 1;
//         return newItemId;
//     }

//     function totalSupply() public view returns (uint256) {
//         return _tokenIdCounter;
//     }
// }


pragma solidity ^0.8.0;

// Import the OpenZeppelin ERC721 implementation and other required contracts
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BasicERC721 is ERC721URIStorage, Ownable {
    uint256 public tokenCounter;

    constructor() ERC721("BasicERC721Token", "B721") Ownable(msg.sender) {
        tokenCounter = 0;
    }

    function createCollectible(string memory tokenURI) public onlyOwner returns (uint256) {
        uint256 newItemId = tokenCounter;
        _safeMint(msg.sender, newItemId);
        _setTokenURI(newItemId, tokenURI);
        tokenCounter = tokenCounter + 1;
        return newItemId;
    }
}
