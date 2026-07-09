# warhammer-mod-development generic

这是《全面战争：战锤3》MOD 开发 skill 的通用版。

本版使用 `custom_` 作为示例前缀。实际开发时可以把 `custom_` 批量替换为你自己的 MOD 前缀，例如 `my_`、`abc_`、`yourmod_`。

目录结构：

```text
warhammer-mod-development_generic/
├── SKILL.md
├── CHANGELOG.md
├── README.md
├── MANIFEST.md
└── references/
    ├── common_effect_keys.md
    ├── lua_api.md
    ├── naming_conventions.md
    ├── project_structure.md
    ├── rpfm_and_verification_workflow.md
    ├── tsv_format.md
    └── unit_creation_workflow.md
```

使用方法：

1. 将 `SKILL.md` 放入 skill 根目录。
2. 将 `references/` 整个目录放在 `SKILL.md` 同级。
3. 真实项目里，把示例前缀 `custom_` 替换为自己的唯一前缀。
4. 后续新增实测经验时，优先写入 reference，并标注验证状态。
