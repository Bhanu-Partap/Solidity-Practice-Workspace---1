// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import "./Proxy/BeaconProxyNFTdynamic.sol";
import "@openzeppelin/contracts-upgradeable@4.9.6/access/OwnableUpgradeable.sol";
import "./ERC721Dynmic.sol";
import "hardhat/console.sol";

contract FactoryNFTcreator is OwnableUpgradeable {
    struct Project {
        address owner;
        uint256 AssetCount;
        address NFTAddress;
        string AssetName;
        string AssetSymbol;
    }

    struct CertifierRole {
        address Certifier;
        address CertifierOnchainId;
        string Role;
    }
    uint256 public ProjectID;
    modifier onlyAdmin() {
        require(msg.sender == Admin, "Caller must be admin");
        _;
    }
    mapping(uint256 => Project) public Assets;
    mapping(address => uint256) collectionToProjectId;
    mapping(address => uint256) ownerToProjectId;

    address public Admin;

    function init(address admin) public initializer {
        __Ownable_init();

        Admin = admin;
    }

    // console.log(owner());

    function createProject(
        address beaconAddress,
        address _owner,
        address Idfactory,
        string memory assetName,
        string memory assetSymbol,
        CertifierRole[] memory team,
        uint256 count
    ) public onlyAdmin {
        ProjectID++;
        address assetCollection = address(
            new nftCollectionBeacon(
                beaconAddress,
                assetName,
                assetSymbol,
                Idfactory,
                Admin,
                _owner
            )
        );
        //  DynamicNFT(assetCollection).SetCertifier(team);
        collectionToProjectId[assetCollection] = ProjectID;
        ownerToProjectId[_owner] = ProjectID;

        for (uint256 i = 0; i < team.length; i++) {
            DynamicNFT(assetCollection).SetCertifier(
                team[i].Certifier,
                team[i].CertifierOnchainId,
                team[i].Role
            );
            // Assets[ProjectID].Certifiers.push(
            //     CertifierRole({
            //         Certifier: team[i].Certifier,
            //         Role: team[i].Role
            //     })
            // );
        }
        Assets[ProjectID].NFTAddress = assetCollection;
        Assets[ProjectID].owner = _owner;

        Assets[ProjectID].AssetCount = count;
        Assets[ProjectID].AssetName = assetName;
        Assets[ProjectID].AssetSymbol = assetSymbol;
    }

    function AddCertifiers(uint256 projectId, CertifierRole[] memory team)
        public
        onlyAdmin
        returns (string memory)
    {
        for (uint256 i = 0; i < team.length; i++) {
            DynamicNFT(Assets[projectId].NFTAddress).SetCertifier(
                team[i].Certifier,
                team[i].CertifierOnchainId,
                team[i].Role
            );
            // Assets[ProjectID].Certifiers.push(
            //     CertifierRole({
            //         Certifier: team[i].Certifier,
            //         Role: team[i].Role
            //     })
            // );
        }

        return "Added certifier Successfully";
    }
}
