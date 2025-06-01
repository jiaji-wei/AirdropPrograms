import { StandardMerkleTree } from "@openzeppelin/merkle-tree";
import fs from "fs";
import express from "express";
import cors from "cors";
import { ethers } from "ethers";

// load merkle tree or create new one
// const merkleTree = StandardMerkleTree.load(JSON.parse(fs.readFileSync("config/rewardProgram1.json", "utf8")));

const wl = JSON.parse(fs.readFileSync("config/wl.json", "utf8"));
const validList = [];
let totalAmount = 0;
for (const [address, amount] of wl.rewardProgram1) {
  // check address is valid
  if (!ethers.isAddress(address)) {
    console.log("invalid address:", address);
    continue;
  }
  validList.push([address, amount]);
  totalAmount += amount;
}
const merkleTree = StandardMerkleTree.of(validList, ["address", "uint256"]);

// save merkle tree to file
fs.writeFileSync("config/rewardProgram1.json", JSON.stringify(merkleTree.dump()));

// (2)
const programName = "rewardProgram1";
const id = ethers.keccak256(ethers.toUtf8Bytes(programName));
console.log("programName:", programName);
console.log("id:", id);
const root = merkleTree.root;
console.log("root:", root);
console.log("totalAmount:", totalAmount);
console.log("rewardAddressNum:", validList.length);

const app = express();
const PORT = process.env.PORT || 9192;

const corsOptions = {
  origin: ["http://localhost:3000"],
  methods: ["GET"], // only allow GET request
  allowedHeaders: ["Content-Type", "Authorization"],
  maxAge: 86400, // preflight request result can be cached for 24 hours
};

app.use(cors(corsOptions));

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

    for (const [i, v] of merkleTree.entries()) {
      if (v[0] === normalizedAddress) {
        proof = merkleTree.getProof(i);
        rewardAmount = v[1];
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
