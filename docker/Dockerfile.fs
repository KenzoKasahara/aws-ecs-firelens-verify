# 検証3（filesystem バッファ化）専用イメージ。
# CMD を上書きし、FireLens 生成設定（/fluent-bit/etc/fluent-bit.conf）ではなく
# 自前のフル設定を読み込ませることで、forward input を filesystem 化する。
FROM public.ecr.aws/aws-observability/aws-for-fluent-bit:3
COPY fluent-bit-fs.conf /fluent-bit/alt/fluent-bit.conf
CMD ["/fluent-bit/bin/fluent-bit", "-c", "/fluent-bit/alt/fluent-bit.conf"]
