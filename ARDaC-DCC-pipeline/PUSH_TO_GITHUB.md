# 上传到 GitHub 的步骤

在你自己的「终端 / Terminal」里执行（不要用其他工具，权限才够）：

```bash
cd ~/Documents/IU/ARDaC_organized/ARDaC-DCC-pipeline

git init -b main
git add -A
git status          # 确认列出的只有 ipynb / sas / yaml / md / 模板 tsv
git commit -m "Initial commit: ARDaC/AlcHepNet DCC submission pipeline"
```

然后在 GitHub 上新建一个空仓库（建议先选 **Private**），再执行：

```bash
git remote add origin https://github.com/<你的用户名>/ARDaC-DCC-pipeline.git
git push -u origin main
```

## 上传前最后检查

```bash
git ls-files            # 应该正好 23 个文件，全部是代码/模板
git ls-files | wc -l
```

不应出现任何 `.csv` / `.xlsx` / `.sas7bdat`，以及除 `templates/` 以外的 `.tsv`。

> 提示：`ARDaC_organized/_to_delete/` 里是可以直接删掉的东西
> （一个在沙盒里生成、带残留锁文件的 .git 目录）。
