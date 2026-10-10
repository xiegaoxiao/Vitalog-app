# AI 计划格式 v1

应用一键生成的提示词包含格式示例。支持纯 JSON 或外层一个 `json` 代码块；计划与备份是两种不同文件，不应混用。

```json
{
  "schemaVersion": 1,
  "range": { "start": "2026-10-12", "end": "2026-10-18" },
  "modules": ["meal", "workout"],
  "events": [
    {
      "id": "20261012-lunch",
      "kind": "meal",
      "title": "土豆鸡胸肉蔬菜汤",
      "start": "2026-10-12T12:00:00+08:00",
      "end": "2026-10-12T12:30:00+08:00",
      "priority": "quiet",
      "reminder": false,
      "leadMinutes": 0,
      "alarm": false,
      "details": {
        "slot": "午餐",
        "minutes": 20,
        "nutrition": { "calories": null, "protein": null, "carbs": null, "fat": null },
        "ingredients": [
          { "name": "土豆", "quantity": 300, "unit": "g" },
          { "name": "鸡胸肉", "quantity": 150, "unit": "g" },
          { "name": "小白菜", "quantity": 200, "unit": "g" }
        ],
        "steps": ["食材洗净切好。", "先将土豆煮软，再加鸡肉充分煮熟，最后加蔬菜与调料。"],
        "notes": "这里只演示格式，营养请根据真实计划估算。"
      }
    },
    {
      "id": "20261012-training-a",
      "kind": "workout",
      "title": "全身训练 A",
      "start": "2026-10-12T16:30:00+08:00",
      "end": "2026-10-12T17:30:00+08:00",
      "priority": "normal",
      "reminder": true,
      "leadMinutes": 0,
      "alarm": false,
      "details": {
        "exercises": [
          { "name": "坐姿推胸", "sets": 2, "reps": 10, "weight": null, "rest_seconds": 90, "notes": "按自己的能力选择重量。" },
          { "name": "平板支撑", "sets": 2, "seconds": 30, "rest_seconds": 60 }
        ],
        "notes": "示例动作应由 AI 根据场地和身体条件调整。"
      }
    }
  ]
}
```

## 规则

- `range` 两端为包含在内的自然日，周期最多 367 天；最多 1000 个事件、文件最多 2 MB。
- 每个 `id` 唯一且稳定，避免重新导入时产生重复记录。
- `kind`：`meal`、`workout`、`course`、`meeting`、`habit`、`other`。
- `modules` 表示本次计划覆盖的模块；事件不能包含未声明模块。可以省略，应用从事件推断。
- 日期时间为 ISO 8601。中国时区推荐显式写 `+08:00`。开始日期必须在 range 内，结束晚于开始，单项最多 48 小时。
- `priority`：`important`、`normal`、`quiet`。`quiet` 不发送通知。`reminder` 控制是否提醒，`leadMinutes` 为 0～1440 的整数，`alarm` 默认 false。
- `nutrition` 单位依次是 kcal、g、g、g；未知留 null 或省略，禁止伪造 0。允许用户修改。
- 食材数量必须非负，名称与库存保持一致。质量单位支持 kg/斤/g，体积支持 l/ml。枚、个、袋等不能无依据互换。
- 动作 `sets` 为 1～30 的整数；可用 `reps` 或 `seconds`；重量未知留 null；休息秒数最多 1800。
- 外部计划不提供 `completedAt`、`actual`、`deductions`。执行状态由应用保存，导入无法覆盖完成历史。

## 替换、冲突和课表

默认替换对应模块/日期的未完成计划。固定课程、组会、完成记录保留；同 ID 及同模块同开始时间的完成事项跳过。追加模式不移除旧计划。

预览会标出时间重叠，允许逐项修改或移除。重叠是提示而不是硬性禁止，因为餐食或通勤等可能由用户有意安排。

`.ics` 直接导入课表，默认重要、提前 15 分钟、不开启持续闹钟。相同 UID 和发生时间不会重复加入。按月/年及复杂位置规则请先展开；未知时区明确报错。

## 备份

备份导出包含 `profile/events/inventory/weights/sleeps/habits/settings` 与 `schemaVersion`，使用「备份与恢复」入口。备份会校验库存关联、数据类型与时间，恢复前显示摘要；恢复后需要检查安卓权限并重建提醒。
