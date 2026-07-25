> ## ⚠️⚠️⚠️⚠️⚠️ 重要警告 / IMPORTANT WARNING ⚠️⚠️⚠️⚠️⚠️
>
> **注意！！请在系统提示词 `CLAUDE.md` 中添加关于此 skill 的描述，否则 agent 不一定会调用这个 skill！！！**
>
> **NOTE!! Please add a description of this skill in the system prompt file `CLAUDE.md`, otherwise the agent may not invoke this skill!!!**
>
>
>
>.

# GB2312 ↔ UTF-8 编码转换编辑 Skill

被CC Bash工具产生的GB2312&UTF-8编码问题折磨的够呛，遂拷打大肥鱼撰写了一个skill，方便文件编辑。

一般修改流程如下：

1. 复制原始文件至临时文件夹（备份件）
2. 将备份件（GB2312）另存为一个UTF8编码的文件
3. 对UTF8文件进行编辑
4. 将修改好的UTF8文件转码回GB2312，覆盖原始文件。

回滚流程：

将上面“2. 将备份件（GB2312）……”中的备份文件丢回原目录

临时文件管理等具体流程请查阅 `skill.md`。

---

# GB2312 ↔ UTF-8 Encoding Conversion Editing Skill

Tired of being tortured by GB2312 and UTF-8 encoding issues caused by CC Bash tools, so I asked deepseek to write this skill to make file editing easier.

General modification workflow:

1. Copy the original file to a temporary folder as a backup.
2. Save the backup (GB2312) as a UTF-8 encoded file.
3. Edit the UTF-8 file.
4. Convert the edited UTF-8 file back to GB2312 and overwrite the original file.

Rollback workflow:

Simply copy the backup file from step 2 back to the original directory.

For temp files management & more detailed steps, refer to `skill.md`.
