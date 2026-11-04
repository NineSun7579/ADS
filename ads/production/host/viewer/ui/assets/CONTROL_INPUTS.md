# 控件状态与测距输入

圆形图标按实际矢量轮廓居中。静息状态降低整个控件的亮度，活动状态保留原稿颜色。

- 行驶/停止：同组互斥保持；点击后代表界面选择，仍通过 `actionTriggered` 发出业务请求。
- 左转/直行/右转车道：同组互斥保持，与行驶状态分开。
- 变道：触发按钮，默认活动配色，按住时变暗，释放恢复；不会成为保持选中。
- 下一步行动预测：只读输出，初始静息。业务输入令相应预测卡片活动，不与车道按钮选择联动。

业务层可用 `DesignView::setBindingValue(binding, value, channelIndex)` 回传视觉状态；`ui.*` 使用 `normal/active/disabled/warning`。也可在 `PerceptionState::visualStates` 中批量传入，更新到界面时会覆盖对应选择。按钮点亮不代表车辆已经执行或获得行驶许可。

```cpp
view->setBindingValue("ui.drive", "active");
view->setBindingValue("ui.stop", "normal");
view->setBindingValue("ui.predictionLeft", "active");
view->setBindingValue("ui.predictionStraight", "normal");
// 预测各项独立可控，清除输出时把所有 ui.prediction* 设为 normal。
```

测距有两个独立输入，通道 0 是前视，1 是后视：

```cpp
view->setBindingValue("channel.distanceValue", 18.6, 0); // 米，显示一位小数
view->setBindingValue("channel.distanceSegments", 6, 0); // 从左往右点亮的段数
view->setBindingValue("channel.distanceUnit", QStringLiteral("米"), 0);
```

亮段数为 0 时全部静息；超出总段数时全部点亮。数值不自动推导亮段数，比例规则留给业务端。实时数据还可通过 `ChannelState::distanceMeters` 和新增的 `distanceSegments` 一并传入；未连接时数字为空值、亮段数归零。

桌面设计预览按 **F2** 打开输入调节面板，可独立调节前后视数字、亮段数和预测输出。调节仅用于界面验证，不产生真实测量或控制车辆。

导出资源中的交互与亮段字段需要板端 v2 消费程序接入；只替换 JSON 不会给未实现这些字段的运行端增加状态逻辑。
