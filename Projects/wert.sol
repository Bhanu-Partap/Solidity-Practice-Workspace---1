// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import "./Ownable.sol";
// import "./ERC721Enumerable.sol";
// import "./IERC20.sol";
// import "./Address.sol";
// import "./SafeMath.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin@3.0/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";

/**
 * @title Wert SampleNFT Contract
 * @dev Extends ERC721 Non-Fungible Token Standard basic implementation
 */
contract WertSampleNFT is ERC721Enumerable, Ownable {
    using SafeMath for uint256;

    string private _baseURL;
    address private _coinAddress;
    uint256 private ethPrice = 5**15;
    uint256 private tokenPrice = 10**19;
    event Transaction(address from, string txType);

    constructor(string memory name, string memory symbol)
        ERC721(name, symbol)
    {}

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    function setBaseURL(string memory newBaseURL) external onlyOwner {
        _baseURL = newBaseURL;
    }

    function setCoinAddress(address newCoinAddress) external onlyOwner {
        _coinAddress = newCoinAddress;
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseURL;
    }

    function mintNFT(address to, uint256 numberOfTokens) external payable {
        require(
            ethPrice.mul(numberOfTokens) <= msg.value,
            "Ether value sent is not correct"
        );
        _mintMultiple(to, numberOfTokens);
        emit Transaction(msg.sender, "sc");
    }

    function mintNFTWithToken(address to, uint256 numberOfTokens) external {
        IERC20(_coinAddress).transferFrom(
            msg.sender,
            address(this),
            tokenPrice.mul(numberOfTokens)
        );
        _mintMultiple(to, numberOfTokens);
        emit Transaction(msg.sender, "erc-sc");
    }

    function _mintMultiple(address to, uint256 numberOfTokens) internal {
        for (uint256 i = 0; i < numberOfTokens; i++) {
            uint256 mintIndex = totalSupply();
            _safeMint(to, mintIndex);
        }
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        string memory baseURL = _baseURI();
        // This is a sample nft - so we can return the same URL every time: <baseURL>/wert_sample_nft
        return
            bytes(baseURL).length > 0
                ? string(abi.encodePacked(baseURL, "wert_sample_nft"))
                : "";
    }
}                                                                
