# Test Coverage Improvement Plan

**Current Coverage:** 60.64% (2143/3534 lines)  
**Target Coverage:** 80%+  
**Gap:** ~686 lines cần cover (19.36%)

**Last Updated:** 2025-11-19

---

## 📊 Coverage Overview by Layer

| Layer | Current | Target | Status | Priority |
|-------|---------|--------|--------|----------|
| **Domain Layer** | 55.4% | 100% | 🔴 Low | **HIGH** |
| **Data Layer** | 56.6% | 90% | 🔴 Low | **HIGH** |
| **Presentation Layer** | 57.1% | 80% | 🔴 Low | Medium |
| **Core Layer** | 60.6% | 90% | 🟡 Medium | **HIGH** |
| **Shared Layer** | 61.8% | 80% | 🟡 Medium | Low |

---

## 🎯 Priority 1: Domain Layer - Use Cases (HIGHEST IMPACT)

**Current:** 57.4% | **Target:** 100% | **Impact:** ~440 lines

### Tasks Use Cases (20-38% coverage)

- [ ] **CreateTaskUseCase** (38% → 100%)
  - [ ] Test edge cases: empty title, very long title
  - [ ] Test validation errors
  - [ ] Test with different task properties
  - **File:** `test/features/tasks/domain/usecases/create_task_usecase_test.dart`
  - **Estimated:** 2-3 tests

- [ ] **DeleteTaskUseCase** (32% → 100%)
  - [ ] Test deleting non-existent task
  - [ ] Test error handling
  - [ ] Test with different task IDs
  - **File:** `test/features/tasks/domain/usecases/delete_task_usecase_test.dart`
  - **Estimated:** 2-3 tests

- [ ] **GetAllTasksUseCase** (29% → 100%)
  - [ ] Test with filters/sorting
  - [ ] Test pagination scenarios
  - [ ] Test error scenarios
  - **File:** `test/features/tasks/domain/usecases/get_all_tasks_usecase_test.dart`
  - **Estimated:** 3-4 tests

- [ ] **GetTaskByIdUseCase** (26% → 100%)
  - [ ] Test with invalid IDs
  - [ ] Test error handling edge cases
  - [ ] Test with special characters in ID
  - **File:** `test/features/tasks/domain/usecases/get_task_by_id_usecase_test.dart`
  - **Estimated:** 2-3 tests

- [ ] **ToggleTaskCompletionUseCase** (23% → 100%)
  - [ ] Test toggling already completed task
  - [ ] Test error scenarios
  - [ ] Test with different task states
  - **File:** `test/features/tasks/domain/usecases/toggle_task_completion_usecase_test.dart`
  - **Estimated:** 3-4 tests

- [ ] **UpdateTaskUseCase** (20% → 100%)
  - [ ] Test partial updates
  - [ ] Test validation errors
  - [ ] Test with all fields
  - [ ] Test error scenarios
  - **File:** `test/features/tasks/domain/usecases/update_task_usecase_test.dart`
  - **Estimated:** 4-5 tests

**Total Estimated Tests:** 16-22 tests  
**Expected Coverage Gain:** ~15-20%

---

## 🎯 Priority 2: Core Layer - Network Interceptors (HIGH IMPACT)

**Current:** 2-40% | **Target:** 90%+ | **Impact:** ~200 lines

- [ ] **ApiLoggingInterceptor** (2% → 90%)
  - [ ] Test request logging
  - [ ] Test response logging
  - [ ] Test error logging
  - [ ] Test with different log levels
  - **File:** `test/core/network/interceptors/api_logging_interceptor_test.dart` (NEW)
  - **Estimated:** 8-10 tests

- [ ] **CacheInterceptor** (32% → 90%)
  - [ ] Test cache hit scenarios
  - [ ] Test cache miss scenarios
  - [ ] Test cache expiration
  - [ ] Test cache invalidation
  - [ ] Test with different HTTP methods
  - **File:** `test/core/network/interceptors/cache_interceptor_test.dart` (NEW)
  - **Estimated:** 6-8 tests

- [ ] **ErrorInterceptor** (40% → 90%)
  - [ ] Test different error types
  - [ ] Test error transformation
  - [ ] Test retry logic
  - [ ] Test error handling edge cases
  - **File:** `test/core/network/interceptors/error_interceptor_test.dart` (EXISTS - improve)
  - **Estimated:** 4-6 tests

- [ ] **LoggingInterceptor** (35% → 90%)
  - [ ] Test request/response logging
  - [ ] Test sensitive data masking
  - [ ] Test different log formats
  - **File:** `test/core/network/interceptors/logging_interceptor_test.dart` (EXISTS - improve)
  - **Estimated:** 4-6 tests

- [ ] **PerformanceInterceptor** (20% → 90%)
  - [ ] Test performance tracking
  - [ ] Test metrics collection
  - [ ] Test slow request detection
  - [ ] Test performance thresholds
  - **File:** `test/core/network/interceptors/performance_interceptor_test.dart` (NEW)
  - **Estimated:** 6-8 tests

**Total Estimated Tests:** 28-38 tests  
**Expected Coverage Gain:** ~8-10%

---

## 🎯 Priority 3: Core Layer - Logging Services (MEDIUM IMPACT)

**Current:** 16-34% | **Target:** 90%+ | **Impact:** ~150 lines

- [ ] **LoggingService** (34% → 90%)
  - [ ] Test different log levels
  - [ ] Test log formatting
  - [ ] Test log output destinations
  - [ ] Test log filtering
  - **File:** `test/core/logging/logging_service_test.dart` (NEW)
  - **Estimated:** 8-10 tests

- [ ] **LogOutput** (17% → 90%)
  - [ ] Test console output
  - [ ] Test file output
  - [ ] Test multiple outputs
  - [ ] Test output formatting
  - **File:** `test/core/logging/log_output_test.dart` (NEW)
  - **Estimated:** 6-8 tests

- [ ] **LocalizationService** (16% → 90%)
  - [ ] Test locale switching
  - [ ] Test translation loading
  - [ ] Test fallback locales
  - [ ] Test missing translations
  - **File:** `test/core/localization/localization_service_test.dart` (NEW)
  - **Estimated:** 6-8 tests

**Total Estimated Tests:** 20-26 tests  
**Expected Coverage Gain:** ~5-7%

---

## 🎯 Priority 4: Data Layer (MEDIUM IMPACT)

**Current:** 56.6% | **Target:** 90%+ | **Impact:** ~200 lines

### Repository Implementations (60.1% → 90%)

- [ ] **TasksRepositoryImpl** - Improve existing tests
  - [ ] Test error handling
  - [ ] Test cache synchronization
  - [ ] Test offline scenarios
  - **File:** `test/features/tasks/data/repositories/tasks_repository_impl_test.dart`
  - **Estimated:** 4-6 tests

### Data Sources (57.6% → 90%)

- [ ] **TasksRemoteDataSource** - Improve existing tests
  - [ ] Test network error handling
  - [ ] Test timeout scenarios
  - [ ] Test retry logic
  - **File:** `test/features/tasks/data/datasources/tasks_remote_datasource_test.dart` (NEW)
  - **Estimated:** 6-8 tests

- [ ] **TasksLocalDataSource** - Improve existing tests
  - [ ] Test storage errors
  - [ ] Test data migration
  - [ ] Test concurrent access
  - **File:** `test/features/tasks/data/datasources/tasks_local_datasource_test.dart`
  - **Estimated:** 4-6 tests

### Models (56.2% → 90%)

- [ ] **TaskModel** - Improve existing tests
  - [ ] Test JSON serialization edge cases
  - [ ] Test validation
  - [ ] Test from/to entity conversion
  - **File:** `test/features/tasks/data/models/task_model_test.dart`
  - **Estimated:** 3-5 tests

**Total Estimated Tests:** 17-25 tests  
**Expected Coverage Gain:** ~6-8%

---

## 🎯 Priority 5: Presentation Layer (LOWER IMPACT)

**Current:** 57.1% | **Target:** 80%+ | **Impact:** ~150 lines

### Screens (55.6% → 80%)

- [ ] **TasksListScreen** - Improve existing tests
  - [ ] Test loading states
  - [ ] Test error states
  - [ ] Test empty states
  - [ ] Test user interactions
  - **File:** `test/features/tasks/presentation/screens/tasks_list_screen_test.dart`
  - **Estimated:** 5-7 tests

- [ ] **TaskDetailScreen** - Improve existing tests
  - [ ] Test edit mode
  - [ ] Test delete confirmation
  - [ ] Test navigation
  - **File:** `test/features/tasks/presentation/screens/task_detail_screen_test.dart`
  - **Estimated:** 4-6 tests

### Providers (57.1% → 80%)

- [ ] **TasksProvider** - Improve existing tests
  - [ ] Test state transitions
  - [ ] Test error handling
  - [ ] Test edge cases
  - **File:** `test/features/tasks/presentation/providers/tasks_provider_test.dart`
  - **Estimated:** 4-6 tests

**Total Estimated Tests:** 13-19 tests  
**Expected Coverage Gain:** ~4-5%

---

## 🎯 Priority 6: Core Layer - Other (LOWER PRIORITY)

**Current:** 55-75% | **Target:** 80%+ | **Impact:** ~100 lines

- [ ] **StorageService** (55.7% → 80%)
  - [ ] Test storage errors
  - [ ] Test data persistence
  - [ ] Test migration scenarios
  - **File:** `test/core/storage/storage_service_test.dart`
  - **Estimated:** 4-6 tests

- [ ] **PerformanceService** (57.3% → 80%)
  - [ ] Test performance tracking
  - [ ] Test metrics aggregation
  - [ ] Test threshold detection
  - **File:** `test/core/performance/performance_service_test.dart`
  - **Estimated:** 4-6 tests

- [ ] **Config/Constants** (51-54% → 80%)
  - [ ] Test environment configuration
  - [ ] Test constant values
  - **File:** `test/core/config/env_config_test.dart`, `test/core/constants/*_test.dart`
  - **Estimated:** 3-5 tests

**Total Estimated Tests:** 11-17 tests  
**Expected Coverage Gain:** ~3-4%

---

## 📈 Progress Tracking

### Overall Progress

- **Total Tests Needed:** ~105-147 tests
- **Tests Completed:** 0
- **Tests Remaining:** ~105-147
- **Progress:** 0%

### By Priority

| Priority | Tests Needed | Completed | Progress |
|----------|--------------|-----------|----------|
| Priority 1 (Domain) | 16-22 | 0 | 0% |
| Priority 2 (Interceptors) | 28-38 | 0 | 0% |
| Priority 3 (Logging) | 20-26 | 0 | 0% |
| Priority 4 (Data) | 17-25 | 0 | 0% |
| Priority 5 (Presentation) | 13-19 | 0 | 0% |
| Priority 6 (Core Other) | 11-17 | 0 | 0% |

---

## 🎯 Quick Wins (Start Here!)

These will give the biggest coverage boost with minimal effort:

1. ✅ **Tasks Use Cases** - Add edge cases to existing tests (16-22 tests, ~15-20% gain)
2. ✅ **Network Interceptors** - Create comprehensive tests (28-38 tests, ~8-10% gain)
3. ✅ **Logging Services** - Create new test files (20-26 tests, ~5-7% gain)

**Total Quick Wins:** 64-86 tests → **~28-37% coverage gain** → **Target: 88-97%** ✅

---

## 📝 Testing Guidelines

### Test Structure
- Use AAA pattern (Arrange, Act, Assert)
- One assertion per test (when possible)
- Use descriptive test names
- Mock external dependencies
- Test edge cases and error scenarios

### Coverage Goals
- **Use Cases:** 100% (critical business logic)
- **Repositories:** 90%+
- **Data Sources:** 90%+
- **Screens/Widgets:** 80%+
- **Utilities:** 80%+

### Running Tests
```bash
# Run all tests
flutter test

# Run with coverage
./scripts/test_coverage.sh

# Run with analysis
./scripts/test_coverage.sh --analyze

# Run specific test file
flutter test test/features/tasks/domain/usecases/create_task_usecase_test.dart
```

---

## 🔄 Update Instructions

1. Check off completed items as you finish them
2. Update "Tests Completed" count
3. Re-run coverage analysis: `./scripts/test_coverage.sh --analyze`
4. Update current coverage percentage
5. Update progress percentages

---

## 📅 Timeline Estimate

- **Priority 1 (Domain):** 2-3 days
- **Priority 2 (Interceptors):** 3-4 days
- **Priority 3 (Logging):** 2-3 days
- **Priority 4 (Data):** 2-3 days
- **Priority 5 (Presentation):** 2-3 days
- **Priority 6 (Core Other):** 1-2 days

**Total Estimated Time:** 12-18 days

---

## ✅ Completion Checklist

- [ ] Priority 1: Domain Layer Use Cases
- [ ] Priority 2: Network Interceptors
- [ ] Priority 3: Logging Services
- [ ] Priority 4: Data Layer
- [ ] Priority 5: Presentation Layer
- [ ] Priority 6: Core Layer Other
- [ ] Final coverage check: 80%+
- [ ] All tests passing
- [ ] Code review completed

---

**Last Coverage Check:** Run `./scripts/test_coverage.sh --analyze` to update

