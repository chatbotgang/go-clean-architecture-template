all: build

GIT_BRANCH=$(shell git branch | grep \* | cut -d ' ' -f2)
GIT_REV=$(shell git rev-parse HEAD | cut -c1-7)
BUILD_DATE=$(shell date +%Y-%m-%d.%H:%M:%S)
EXTRA_LD_FLAGS=-X main.AppVersion=${GIT_BRANCH}-${GIT_REV} -X main.AppBuild=${BUILD_DATE}

GOLANGCI_LINT_VERSION="v1.42.1"
DATABASE_DSN="postgresql://cb_test:cb_test@localhost:5432/cb_test?sslmode=disable"
TEST_PACKAGES = ./internal/...

build:
	go build -ldflags '${EXTRA_LD_FLAGS}' -o bin/barter ./cmd/barter

run: build
	./bin/barter \
	--database_dsn=$(DATABASE_DSN) \
	| jq



test:
	go vet $(TEST_PACKAGES)
	go test -race -cover -coverprofile cover.out $(TEST_PACKAGES)
	go tool cover -func=cover.out | tail -n 1

mock:
	@which mockgen > /dev/null || (echo "No mockgen installed. Try: go install github.com/golang/mock/mockgen@v1.6.0"; exit 1)
	@echo "generating mocks..."
	@go generate ./...

clean:
	rm -rf bin/ cover.out

# Migrate db up to date
migrate-db-up:
	docker run --rm -v $(shell pwd)/migrations:/migrations --network host migrate/migrate -verbose -path=/migrations/ -database=$(DATABASE_DSN) up

# Revert db migration once a step
migrate-db-down:
	docker run --rm -v $(shell pwd)/migrations:/migrations --network host migrate/migrate -verbose -path=/migrations/ -database=$(DATABASE_DSN) down 1

# Force the current version to the given number. It is used for manually resolving dirty migration flag.
# Ref: https://github.com/golang-migrate/migrate/blob/master/GETTING_STARTED.md#forcing-your-database-version
migrate-db-force-%:
	docker run --rm -v $(shell pwd)/migrations:/migrations --network host migrate/migrate -verbose -path=/migrations/ -database=$(DATABASE_DSN) force $*

# Only used for local dev
init-local-db:
	docker exec cb-postgres bash -c "psql -U cb_test -d cb_test -f /testdata/init_local_dev.sql"
