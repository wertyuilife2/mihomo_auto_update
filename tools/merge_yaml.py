#!/usr/bin/env python3
import sys
from pathlib import Path

import yaml


def merge_rules(base, override):
    if base is None:
        return list(override)

    if not isinstance(base, list) or not isinstance(override, list):
        raise ValueError("top-level rules must be lists")

    return list(override) + list(base)


def merge(base, override, *, is_root=False):
    if isinstance(base, dict) and isinstance(override, dict):
        merged = dict(base)
        for key, value in override.items():
            # 对于顶层的 "rules" 键，使用特殊的合并逻辑
            if is_root and key == "rules":
                merged[key] = merge_rules(merged.get(key), value)
                continue
            
            # 直接覆盖，不进行递归合并
            merged[key] = value
            
            # 如果需要递归合并，可以取消注释以下代码
            # if key in merged:
            #     merged[key] = merge(merged[key], value)
            # else:
            #     merged[key] = value
        return merged
    return override


def load_yaml(path_str):
    path = Path(path_str)
    with path.open("r", encoding="utf-8") as handle:
        data = yaml.safe_load(handle)

    if data is None:
        data = {}

    if not isinstance(data, dict):
        raise ValueError(f"{path} must be a mapping at the top level")

    return data


def main():
    if len(sys.argv) != 4:
        print("usage: merge_yaml.py <base.yaml> <override.yaml> <output.yaml>", file=sys.stderr)
        return 1

    base = load_yaml(sys.argv[1])
    override = load_yaml(sys.argv[2])
    merged = merge(base, override, is_root=True)

    output_path = Path(sys.argv[3])
    with output_path.open("w", encoding="utf-8") as handle:
        yaml.safe_dump(merged, handle, sort_keys=False, allow_unicode=True)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
