// Stubbed implementation of the kafka package, to enable co-existence
// in code that can be used either in Web or non-Web targets.
class Producer<K, V> {
  final Serializer<K> keySerializer;
  final Serializer<V> valueSerializer;
  final ProducerConfig config;

  Producer(this.keySerializer, this.valueSerializer, this.config);

  void add(ProducerRecord record) {
    throw ('not implemented');
  }
}

class ProducerRecord<K, V> {
  final String? topic;
  final int partition;
  final K key;
  final V value;
  final int? timestamp;

  ProducerRecord(this.topic, this.partition, this.key, this.value,
      {this.timestamp});
}

class ProducerConfig {
  final List<String> bootstrapServers;

  ProducerConfig({required this.bootstrapServers});
}

abstract class Serializer<T> {
  List<int> serialize(T data);
}

/// Serializer for `String` objects. Defaults to UTF8 encoding.
class StringSerializer implements Serializer<String> {
  @override
  List<int> serialize(String data) {
    throw ('not implemented');
  }
}
