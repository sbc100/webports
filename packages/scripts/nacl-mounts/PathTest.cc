/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#include "gtest/gtest.h"
#include "Path.h"

TEST(PathTest, SanityChecks) {
  // can we construct and delete?
  Path ph1(".");
  Path *ph2 = new Path(".");
  delete ph2;

  Path p1(".");
  EXPECT_EQ(false, p1.is_absolute());
  EXPECT_EQ("", p1.FormulatePath());
  Path p2("/");
  EXPECT_EQ(true, p2.is_absolute());
  EXPECT_EQ("/", p2.FormulatePath());
  Path p3 = p2.AppendPath("hello/world/");
  EXPECT_EQ("/hello/world", p3.FormulatePath());
}

TEST(PathTest, Split) {
  std::list<std::string> path_components;
  std::list<std::string>::iterator it;

  Path p1("/simple/splitter/test");
  path_components = p1.path();
  EXPECT_EQ(3, static_cast<int>(path_components.size()));
  it = path_components.begin();
  EXPECT_EQ("simple", *it);
  ++it;
  EXPECT_EQ("splitter", *it);
  ++it;
  EXPECT_EQ("test", *it);

  Path p2("///simple//splitter///test/");
  path_components = p2.path();
  EXPECT_EQ(3, static_cast<int>(path_components.size()));
  it = path_components.begin();
  EXPECT_EQ("simple", *it);
  ++it;
  EXPECT_EQ("splitter", *it);
  ++it;
  EXPECT_EQ("test", *it);

  Path p3("/sim/ple//spli/tter/te/st/");
  path_components = p3.path();
  EXPECT_EQ(6, static_cast<int>(path_components.size()));
  it = path_components.begin();
  EXPECT_EQ("sim", *it);
  ++it;
  EXPECT_EQ("ple", *it);
  ++it;
  EXPECT_EQ("spli", *it);
  ++it;
  EXPECT_EQ("tter", *it);
  ++it;
  EXPECT_EQ("te", *it);
  ++it;
  EXPECT_EQ("st", *it);

  Path p4("");
  path_components = p4.path();
  EXPECT_EQ(0, static_cast<int>(path_components.size()));

  Path p5("/");
  path_components = p5.path();
  EXPECT_EQ(0, static_cast<int>(path_components.size()));
}

TEST(PathTest, AppendPathAndFormulatePath) {
  Path ph1("/usr/local/hi/there");
  EXPECT_EQ("/usr/local/hi/there", ph1.FormulatePath());
  ph1 = ph1.AppendPath("..");
  EXPECT_EQ("/usr/local/hi", ph1.FormulatePath());
  ph1 = ph1.AppendPath(".././././hi/there/../.././././");
  EXPECT_EQ("/usr/local", ph1.FormulatePath());
  ph1 = ph1.AppendPath("../../../../../../../../././../");
  EXPECT_EQ("/", ph1.FormulatePath());
  ph1 = ph1.AppendPath("usr/lib/../bin/.././etc/../local/../share");
  EXPECT_EQ("/usr/share", ph1.FormulatePath());

  Path ph2("./");
  EXPECT_EQ("", ph2.FormulatePath());

  Path ph3("/");
  EXPECT_EQ("/", ph3.FormulatePath());
  ph3 = ph3.AppendPath("");
  EXPECT_EQ("/", ph3.FormulatePath());
  ph3 = ph3.AppendPath("USR/local/SHARE");
  EXPECT_EQ("/USR/local/SHARE", ph3.FormulatePath());
  ph3 = ph3.AppendPath("///////////////////////////////");
  EXPECT_EQ("/USR/local/SHARE", ph3.FormulatePath());

  Path ph4("..");
  EXPECT_EQ("", ph4.FormulatePath());
  ph4 = ph4.AppendPath("/node1/node3/../../node1/./");
  EXPECT_EQ("/node1", ph4.FormulatePath());
  ph4 = ph4.AppendPath("node4/../../node1/./node5");
  EXPECT_EQ("/node1/node5", ph4.FormulatePath());
}
