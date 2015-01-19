/*
 * Copyright (C) 2014 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "nodes.h"
#include "parallel_move_resolver.h"
#include "utils/arena_allocator.h"

#include "gtest/gtest.h"

namespace art {

class TestParallelMoveResolver : public ParallelMoveResolver {
 public:
  explicit TestParallelMoveResolver(ArenaAllocator* allocator) : ParallelMoveResolver(allocator) {}

  void Dump(Location location) {
    if (location.IsConstant()) {
      message_ << "C";
    } else if (location.IsPair()) {
      message_ << location.low() << "," << location.high();
    } else {
      message_ << location.reg();
    }
  }

  virtual void EmitMove(size_t index) {
    MoveOperands* move = moves_.Get(index);
    if (!message_.str().empty()) {
      message_ << " ";
    }
    message_ << "(";
    Dump(move->GetSource());
    message_ << " -> ";
    Dump(move->GetDestination());
    message_ << ")";
  }

  virtual void EmitSwap(size_t index) {
    MoveOperands* move = moves_.Get(index);
    if (!message_.str().empty()) {
      message_ << " ";
    }
    message_ << "(";
    Dump(move->GetSource());
    message_ << " <-> ";
    Dump(move->GetDestination());
    message_ << ")";
  }

  virtual void SpillScratch(int reg ATTRIBUTE_UNUSED) {}
  virtual void RestoreScratch(int reg ATTRIBUTE_UNUSED) {}

  std::string GetMessage() const {
    return  message_.str();
  }

 private:
  std::ostringstream message_;


  DISALLOW_COPY_AND_ASSIGN(TestParallelMoveResolver);
};

static HParallelMove* BuildParallelMove(ArenaAllocator* allocator,
                                        const size_t operands[][2],
                                        size_t number_of_moves) {
  HParallelMove* moves = new (allocator) HParallelMove(allocator);
  for (size_t i = 0; i < number_of_moves; ++i) {
    moves->AddMove(
        Location::RegisterLocation(operands[i][0]),
        Location::RegisterLocation(operands[i][1]),
        nullptr);
  }
  return moves;
}

TEST(ParallelMoveTest, Dependency) {
  ArenaPool pool;
  ArenaAllocator allocator(&pool);

  {
    TestParallelMoveResolver resolver(&allocator);
    static constexpr size_t moves[][2] = {{0, 1}, {1, 2}};
    resolver.EmitNativeCode(BuildParallelMove(&allocator, moves, arraysize(moves)));
    ASSERT_STREQ("(1 -> 2) (0 -> 1)", resolver.GetMessage().c_str());
  }

  {
    TestParallelMoveResolver resolver(&allocator);
    static constexpr size_t moves[][2] = {{0, 1}, {1, 2}, {2, 3}, {1, 4}};
    resolver.EmitNativeCode(BuildParallelMove(&allocator, moves, arraysize(moves)));
    ASSERT_STREQ("(2 -> 3) (1 -> 2) (1 -> 4) (0 -> 1)", resolver.GetMessage().c_str());
  }
}

TEST(ParallelMoveTest, Swap) {
  ArenaPool pool;
  ArenaAllocator allocator(&pool);

  {
    TestParallelMoveResolver resolver(&allocator);
    static constexpr size_t moves[][2] = {{0, 1}, {1, 0}};
    resolver.EmitNativeCode(BuildParallelMove(&allocator, moves, arraysize(moves)));
    ASSERT_STREQ("(1 <-> 0)", resolver.GetMessage().c_str());
  }

  {
    TestParallelMoveResolver resolver(&allocator);
    static constexpr size_t moves[][2] = {{0, 1}, {1, 2}, {1, 0}};
    resolver.EmitNativeCode(BuildParallelMove(&allocator, moves, arraysize(moves)));
    ASSERT_STREQ("(1 -> 2) (1 <-> 0)", resolver.GetMessage().c_str());
  }

  {
    TestParallelMoveResolver resolver(&allocator);
    static constexpr size_t moves[][2] = {{0, 1}, {1, 2}, {2, 3}, {3, 4}, {4, 0}};
    resolver.EmitNativeCode(BuildParallelMove(&allocator, moves, arraysize(moves)));
    ASSERT_STREQ("(4 <-> 0) (3 <-> 4) (2 <-> 3) (1 <-> 2)", resolver.GetMessage().c_str());
  }
}

TEST(ParallelMoveTest, ConstantLast) {
  ArenaPool pool;
  ArenaAllocator allocator(&pool);
  TestParallelMoveResolver resolver(&allocator);
  HParallelMove* moves = new (&allocator) HParallelMove(&allocator);
  moves->AddMove(
      Location::ConstantLocation(new (&allocator) HIntConstant(0)),
      Location::RegisterLocation(0),
      nullptr);
  moves->AddMove(
      Location::RegisterLocation(1),
      Location::RegisterLocation(2),
      nullptr);
  resolver.EmitNativeCode(moves);
  ASSERT_STREQ("(1 -> 2) (C -> 0)", resolver.GetMessage().c_str());
}

TEST(ParallelMoveTest, Pairs) {
  ArenaPool pool;
  ArenaAllocator allocator(&pool);

  {
    TestParallelMoveResolver resolver(&allocator);
    HParallelMove* moves = new (&allocator) HParallelMove(&allocator);
    moves->AddMove(
        Location::RegisterLocation(2),
        Location::RegisterLocation(4),
        nullptr);
    moves->AddMove(
        Location::RegisterPairLocation(0, 1),
        Location::RegisterPairLocation(2, 3),
        nullptr);
    resolver.EmitNativeCode(moves);
    ASSERT_STREQ("(2 -> 4) (0 -> 2) (1 -> 3)", resolver.GetMessage().c_str());
  }

  {
    TestParallelMoveResolver resolver(&allocator);
    HParallelMove* moves = new (&allocator) HParallelMove(&allocator);
    moves->AddMove(
        Location::RegisterPairLocation(0, 1),
        Location::RegisterPairLocation(2, 3),
        nullptr);
    moves->AddMove(
        Location::RegisterLocation(2),
        Location::RegisterLocation(4),
        nullptr);
    resolver.EmitNativeCode(moves);
    ASSERT_STREQ("(2 -> 4) (0 -> 2) (1 -> 3)", resolver.GetMessage().c_str());
  }

  {
    TestParallelMoveResolver resolver(&allocator);
    HParallelMove* moves = new (&allocator) HParallelMove(&allocator);
    moves->AddMove(
        Location::RegisterPairLocation(0, 1),
        Location::RegisterPairLocation(2, 3),
        nullptr);
    moves->AddMove(
        Location::RegisterLocation(2),
        Location::RegisterLocation(0),
        nullptr);
    resolver.EmitNativeCode(moves);
    ASSERT_STREQ("(2 <-> 0) (1 -> 3)", resolver.GetMessage().c_str());
  }
}

}  // namespace art
