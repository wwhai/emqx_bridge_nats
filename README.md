# emqx_bridge_nats: 数据推送到 Nats

## 简介
本插件是把数据桥接到 NNATS 消息队列。
## NATS
NATS是一个开源、轻量级、高性能的分布式消息中间件，实现了高可伸缩性和优雅的Publish/Subscribe模型，使用Golang语言开发。
NATS消息传递支持在计算机应用程序和服务之间交换分段为消息的数据。这些消息由主题解决，不依赖于网络位置。这在应用程序或服务与底层物理网络之间提供了一个抽象层。数据被编码并构成消息并由发布者发送。该消息由一个或多个订户接收，解码和处理。

### 测试环境
```sh
docker run --name nats --rm -p 4222:4222 -p 8222:8222 nats
``` 

## 配置
```ini
##====================================================================
## Configuration for EMQ X NATS Broker Bridge
##====================================================================

## Bridge address: node address for bridge.
##
## Value: String
## Example: 127.0.0.1
bridge.nats.address = 127.0.0.1

## Bridge Port: node port for bridge.
##
## Value: Integer
## Value: Port
bridge.nats.port = 4222

```

## 社区
- QQ群：475512169
- 博客：https://wwhai.github.io