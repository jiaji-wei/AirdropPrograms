import { StandardMerkleTree } from "@openzeppelin/merkle-tree";
import fs from "fs";
import express from "express";
import cors from "cors";
import { ethers } from "ethers";

// load merkle tree or create new one
// const merkleTree = StandardMerkleTree.load(JSON.parse(fs.readFileSync("config/rewardProgram1.json", "utf8")));

const programName = "rewardProgram1"; // usde-week23
const id = ethers.keccak256(ethers.toUtf8Bytes(programName));
console.log("programName:", programName);
console.log("id:", id);


const programName2 = "usde-week24";
const id2 = ethers.keccak256(ethers.toUtf8Bytes(programName2));
console.log("programName2:", programName2);
console.log("id2:", id2);

const wl = JSON.parse(fs.readFileSync("config/wl.json", "utf8"));
const validList = [];
let totalAmount = 0;
for (const [address, amount] of wl.rewardProgram1) {
  // check address is valid
  if (!ethers.isAddress(address)) {
    console.log("invalid address:", address);
    continue;
  }
  validList.push([id, address, amount]);
  totalAmount += amount;
}

const validList2 = [];
let totalAmount2 = 0;
for (const [address, amount] of wl.usdeWeek24) {
  // check address is valid
  if (!ethers.isAddress(address)) {
    console.log("invalid address:", address);
    continue;
  }
  validList2.push([id2, address, amount]);
  totalAmount2 += amount;
}

const merkleTree = StandardMerkleTree.of(validList, ["bytes32", "address", "uint256"]);
const merkleTree2 = StandardMerkleTree.of(validList2, ["bytes32", "address", "uint256"]);

const root = merkleTree.root;
console.log("root:", root);
console.log("totalAmount:", totalAmount);
console.log("rewardAddressNum:", validList.length);

const root2 = merkleTree2.root;
console.log("root2:", root2);
console.log("totalAmount2:", totalAmount2);
console.log("rewardAddressNum2:", validList2.length);

// save merkle tree to file
fs.writeFileSync("config/rewardProgram1.json", JSON.stringify(merkleTree.dump()));
fs.writeFileSync("config/usdeWeek24.json", JSON.stringify(merkleTree2.dump()));
const app = express();
const PORT = process.env.PORT || 9192;

const corsOptions = {
  origin: ["http://localhost:3000"],
  methods: ["GET"], // only allow GET request
  allowedHeaders: ["Content-Type", "Authorization"],
  maxAge: 86400, // preflight request result can be cached for 24 hours
};

app.use(cors(corsOptions));


let mapping = {};
mapping[id] = merkleTree;
mapping[id2] = merkleTree2;

// /proof?address=0x123&programId=0x123  get proof
// /proofs?address=0x123  get all reward program and proofs
app.get("/proof", (req, res) => {
  try {
    const { address, programId } = req.query;

    if (!address) {
      return res.status(400).json({ error: "invalid address" });
    }

    if (!programId) {
      return res.status(400).json({ error: "invalid programId" });
    }

    // TODO: different programId has different merkle tree

    const normalizedAddress = ethers.getAddress(address);

    let proof = null;
    let rewardAmount = 0;

    const merkleTree = mapping[programId];

    for (const [i, v] of merkleTree.entries()) {
      if (v[1] === normalizedAddress) {
        proof = merkleTree.getProof(i);
        rewardAmount = v[2];
        break;
      }
    }

    if (!proof) {
      return res.status(404).json({ error: "not in reward list" });
    }

    return res.json({
      proof,
      rewardAmount,
      programId,
    });
  } catch (error) {
    console.error("internal server error:", error);
    return res.status(500).json({ error: "internal server error" });
  }
});

// 启动服务器
app.listen(PORT, () => {
  console.log(`server running on port ${PORT}`);
});
