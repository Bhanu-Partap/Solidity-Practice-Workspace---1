// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
// contracts/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol
// contracts/access/OwnableUpgradeable.sol
import "@openzeppelin/contracts-upgradeable@4.9.6/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable@4.9.6/access/OwnableUpgradeable.sol";
import "./IdentityFactory.sol";
// import "@openzeppelin/contracts@4.9.6/proxy/utils/Initializable.sol";

contract DynamicNFT is ERC721URIStorageUpgradeable {
    struct CertifierRole {
        address Certifier;
        address CertifierOnchainID;
        string Role;
    }
    address public admin;
    address  public owner;
    modifier  onlyAdmin(){
        require(msg.sender == admin , "Caller must be admin");
        _;
    }
    mapping(uint256 => mapping(address => bool)) nftApprovedByVerifier;
    CertifierRole[] certifier;

    //      string[] IpfsUri = [
    //         "https://api.npoint.io/2367a54a38c79bbe9a95",
    //         "https://api.npoint.io/6bdca0b1ab9c55094110",
    //         "https://api.npoint.io/2367a54a38c79bbe9a95"
    //   ];
    IDfactory private ID_FactoryAddress;

    function initialize(
        string memory name,
        string memory symbol,
        address IDFactoryAddress,
        address _Admin,
        address _Owner
    )public initializer  {
         __ERC721_init(name,symbol);
        ID_FactoryAddress = IDfactory(IDFactoryAddress);
        admin = _Admin;
        owner = _Owner;
    }

    function CertifierExists(address _certifier) public view returns (bool) {
        for (uint256 i = 0; i < certifier.length; i++) {
            if (certifier[i].Certifier == _certifier) {
                return true;
            }
        }
        return false;
    }

    modifier IsCertifiers() {
        require(CertifierExists(msg.sender), "Caller must be a certifier");
        _;
    }

    function SetCertifier(
        address _certifier,
        address _certfierID,
        string memory role
    ) public onlyAdmin {
        certifier.push(
            CertifierRole({
                Certifier: _certifier,
                CertifierOnchainID: _certfierID,
                Role: role
            })
        );
    }

    function isNftApprovedByAllVerifier(uint256 nftid)
        public
        view
        returns (bool)
    {
        bool IsApproved = true;
        for (uint256 i = 0; i < certifier.length; i++) {
            if (!nftApprovedByVerifier[nftid][certifier[i].Certifier]) {
                IsApproved = false;
                break;
            }
        }
        return IsApproved;
    }

    function approveNftByVerifier(uint256 nftId) public IsCertifiers {
        nftApprovedByVerifier[nftId][msg.sender] = true;
    }

    // function BatchApproveByVerifier(uint256[] nftIds)public IsCertifiers {
    //     for(i=0)
    //     nftApprovedByVerifier[nftId][msg.sender] = true;
    // }

    function safeMint(
        address to,
        uint256 tokenId,
        string memory uri
    ) public onlyAdmin  {
        // require(
        //     _tokenIdentityRegistry.isVerified(to),
        //     "Identity is not verified."
        // );
        address verifiedUser = IDfactory(ID_FactoryAddress).getidentity(to);
        require(verifiedUser != address(0), "Not a verified User");
        require(
            isNftApprovedByAllVerifier(tokenId),
            "not approved by verifier"
        );
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    function BatchMint(
        address to,
        uint256[] memory ArrayOfTokenIDs,
        string[] memory URIs
    ) public  {
        for (uint256 i = 0; i < ArrayOfTokenIDs.length; i++) {
            safeMint(to, ArrayOfTokenIDs[i], URIs[i]);
        }
    }

    // function safeTransferFrom(
    //     address from,
    //     address to,
    //     uint256 tokenId
    // ) public virtual override(ERC721Upgradeable,IERC721Upgradeable){
    //     address verifiedUser = IDfactory(ID_FactoryAddress).getidentity(to);
    //     require(verifiedUser != address(0), "Not a verified User");
    //     super._safeTransfer(from, to, tokenId, "");
    // }

    // function safeTransferFrom(
    //     address from,
    //     address to,
    //     uint256 tokenId,
    //     bytes memory data
    // ) public virtual  {
    //     address verifiedUser = IDfactory(ID_FactoryAddress).getidentity(to);
    //     require(verifiedUser != address(0), "Not a verified User");
    //     require(
    //         _isApprovedOrOwner(_msgSender(), tokenId),
    //         "ERC721: caller is not token owner or approved"
    //     );
    //     _safeTransfer(from, to, tokenId, data);
    // }

    function changeUri(uint256 id, string memory metadataLink) public {
        _setTokenURI(id, metadataLink);
    }
}
