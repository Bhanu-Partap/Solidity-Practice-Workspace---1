// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable@4.9.6/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "./IdentityFactory.sol";

contract DynamicNFT is ERC721URIStorageUpgradeable {
    struct SignatoryRole {
        address Signatory;
        address SignatoryOnchainID;
        string Role;
    }

    event assetAdded(address nftAddress, uint256 AssetCount);
    event assetApprovalBySignatory(
        address nftAddress,
        uint256 AssetId,
        address signatoryAddress
    );
    event SignatoryAdded(address NftAddress, address signatory);
    event removedSignatory(address NftAddress, address signatory);

    uint256 nftcount;
    uint256 public AssetCount;
    address public admin;

    address public owner;
    address public vaultAddress;
    address nftfactoryaddress;
    IDfactory public ID_FactoryAddress;

    SignatoryRole[] Signatorys;

    mapping(uint256 => mapping(address => bool)) assetApprovedByVerifier;

    modifier onlyAdmin() {
        require(msg.sender == admin, "Caller must be admin");
        _;
    }
    modifier isSignatory() {
        require(isSignatoryExists(msg.sender), "Caller must be a Signatory");
        _;
    }

    function addAsset(uint256 AddAssetsCount) public {
        require(
            msg.sender == admin || msg.sender == nftfactoryaddress,
            "not authorised"
        );
        AssetCount += AddAssetsCount;
        emit assetAdded(address(this), AddAssetsCount);
    }

    function initialize(
        string memory name,
        string memory symbol,
        address IDFactoryAddress,
        address _Admin,
        address _Owner,
        address _nftfactoryaddress
    ) public initializer {
        __ERC721_init(name, symbol);
        ID_FactoryAddress = IDfactory(IDFactoryAddress);
        admin = _Admin;
        owner = _Owner;
        nftfactoryaddress = _nftfactoryaddress;
    }

    function isVerifiedUser(address userWallet) public view returns (bool) {
        address verifiedUser = ID_FactoryAddress.getidentity(userWallet);
        return verifiedUser != address(0);
    }

    function isSignatoryExists(address _Signatory) public view returns (bool) {
        for (uint256 i = 0; i < Signatorys.length; i++) {
            if (Signatorys[i].Signatory == _Signatory) {
                return true;
            }
        }
        return false;
    }

    // function transferOwnership(address newOwner) public onlyAdmin {
    //     require(newOwner != address(0), "zero address");
    //     owner = newOwner;
    // }

    function setVault(address _vaultAddress) public {
        require(vaultAddress == address(0), "already initialised");
        vaultAddress = _vaultAddress;
    }

    function SetSignatory(
        address _Signatory,
        address _certfierID,
        string memory role
    ) public {
        require(!isSignatoryExists(_Signatory), "Already a Signatory");
        require(
            msg.sender == admin || msg.sender == nftfactoryaddress,
            "not authorised"
        );
        Signatorys.push(
            SignatoryRole({
                Signatory: _Signatory,
                SignatoryOnchainID: _certfierID,
                Role: role
            })
        );
        emit SignatoryAdded(address(this), _Signatory);
    }

    function removeSignatory(address _Signatory) public onlyAdmin {
        require(isSignatoryExists(_Signatory), "not a Signatory");
        require(_Signatory != owner, "Can't remove Owner");
        for (uint8 i = 0; i < Signatorys.length; i++) {
            if (Signatorys[i].Signatory == _Signatory) {
                delete Signatorys[i];
                for (uint8 j = i; j < Signatorys.length - 1; j++) {
                    Signatorys[i] = Signatorys[i + 1];
                }
                Signatorys.pop();
                break;
            }
        }
        for (uint256 assetId = 1; assetId <= AssetCount; assetId++) {
            if (assetApprovedByVerifier[assetId][_Signatory] == true) {
                assetApprovedByVerifier[assetId][_Signatory] = false;
            }
        }
        emit removedSignatory(address(this), _Signatory);
    }

    function approvalPerAsset(uint256 assetId)
        public
        view
        returns (address[] memory, uint8)
    {
        uint8 approvalCount;
        address[] memory assetApprovedBySignatories = new address[](
            Signatorys.length
        );

        for (uint8 i = 0; i < Signatorys.length; i++) {
            if (
                assetApprovedByVerifier[assetId][Signatorys[i].Signatory] ==
                true
            ) {
                assetApprovedBySignatories[approvalCount] = Signatorys[i]
                    .Signatory;
                approvalCount++;
            }
        }
        return (assetApprovedBySignatories, approvalCount);
    }

    function isNftApprovedByAllVerifier(uint256 assetid)
        public
        view
        returns (bool)
    {
        bool IsApproved = true;
        for (uint256 i = 0; i < Signatorys.length; i++) {
            if (!assetApprovedByVerifier[assetid][Signatorys[i].Signatory]) {
                IsApproved = false;
                break;
            }
        }
        return IsApproved;
    }

    function approveNftByVerifier(uint256 assetid) public isSignatory {
        require(
            assetApprovedByVerifier[assetid][msg.sender] != true,
            "Already approved"
        );
        require(AssetCount >= assetid, "need verification of admin firstly");
        assetApprovedByVerifier[assetid][msg.sender] = true;
        emit assetApprovalBySignatory(address(this), assetid, msg.sender);
    }

    function batchApproveByVerifier(uint256[] calldata assetIds)
        public
        isSignatory
    {
        for (uint256 i = 0; i < assetIds.length; i++) {
            approveNftByVerifier(assetIds[i]);
        }
    }

    function safeMint(uint256 assetid, string memory uri) public onlyAdmin {
        require(isVerifiedUser(owner), "Not a verified User");
        require(
            isNftApprovedByAllVerifier(assetid),
            "not approved by verifier"
        );
        nftcount++;
        _safeMint(owner, assetid);
        _setTokenURI(assetid, uri);
        for (uint8 i = 0; i < Signatorys.length; i++) {
            delete assetApprovedByVerifier[assetid][Signatorys[i].Signatory];
        }
    }

    function BatchMint(uint256[] memory ArrayOfTokenIDs, string[] memory URIs)
        public
        onlyAdmin
    {
        for (uint256 i = 0; i < ArrayOfTokenIDs.length; i++) {
            safeMint(ArrayOfTokenIDs[i], URIs[i]);
        }
    }

    function updateNftMetadata(uint256 nftID, string memory metadataLink)
        public
        onlyAdmin
    {
        require(isNftApprovedByAllVerifier(nftID), "not approved by verifier");
        _setTokenURI(nftID, metadataLink);
        for (uint8 i = 0; i < Signatorys.length; i++) {
            delete assetApprovedByVerifier[nftID][Signatorys[i].Signatory];
        }
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 nftId,
        bytes memory data
    ) public virtual override(ERC721Upgradeable, IERC721Upgradeable) {
        require(
            to == vaultAddress || isVerifiedUser(to),
            "Not a verified receiver "
        );
        require(
            isVerifiedUser(from) || from == vaultAddress,
            "Not a verified sender "
        );

        super.safeTransferFrom(from, to, nftId, data);
    }
}
