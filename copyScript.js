const path = require("path");
const fs = require("fs-extra");

const REPO_DIR = path.resolve(__dirname, ".");
const MODULE_DIR = path.join(
  REPO_DIR,
  "example",
  "node_modules",
  "react-native-pdftron"
);

const COPY_FOLDER_LIST = ["android", "ios", "src"];

const toRepo = process.argv[2] === "toRepo";

// The source and destination for copying process
const srcRoot = toRepo ? MODULE_DIR : REPO_DIR;
const dstRoot = toRepo ? REPO_DIR : MODULE_DIR;

console.log(srcRoot);
console.log(dstRoot);

// delete original folders if exist and copy over
for (let folder of COPY_FOLDER_LIST) {
  let src = path.join(srcRoot, folder);
  let dst = path.join(dstRoot, folder);

  if (fs.existsSync(dst)) {
    fs.removeSync(dst);
  }

  fs.copySync(src, dst);
}
