#!/usr/bin/env bash
# Build dist/spriterrific-api-skill.zip. Unzipping it at a project root
# installs the skill under both .claude/skills/ and .agents/skills/.
set -euo pipefail
cd "$(dirname "$0")/.."

rm -rf dist/stage dist/spriterrific-api-skill.zip
mkdir -p dist/stage/.claude/skills dist/stage/.agents/skills
cp -R skills/spriterrific-api dist/stage/.claude/skills/
cp -R skills/spriterrific-api dist/stage/.agents/skills/
(cd dist/stage && zip -rq ../spriterrific-api-skill.zip .claude .agents)
rm -rf dist/stage

echo "Built dist/spriterrific-api-skill.zip:"
unzip -l dist/spriterrific-api-skill.zip
