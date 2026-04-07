ROOT_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

ifneq (,$(wildcard $(ROOT_DIR).env))
  include $(ROOT_DIR).env
  export
endif

prepare:
	cd $(ROOT_DIR) && python scripts/clean_csv.py

run_ecommerce_snowflake: prepare
	cd $(ROOT_DIR) && dbt seed --profiles-dir ./profiles --target snowflake
	cd $(ROOT_DIR) && dbt run --profiles-dir ./profiles --target snowflake

run_ecommerce_duckdb: prepare
	cd $(ROOT_DIR) && dbt seed --profiles-dir ./profiles --target duckdb
	cd $(ROOT_DIR) && dbt run --profiles-dir ./profiles --target duckdb