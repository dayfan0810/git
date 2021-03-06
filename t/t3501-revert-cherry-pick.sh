#!/bin/sh

test_description='test cherry-pick and revert with renames

  --
   + rename2: renames oops to opos
  +  rename1: renames oops to spoo
  +  added:   adds extra line to oops
  ++ initial: has lines in oops

'

. ./test-lib.sh

test_expect_success setup '

	for l in a b c d e f g h i j k l m n o
	do
		echo $l$l$l$l$l$l$l$l$l
	done >oops &&

	test_tick &&
	git add oops &&
	git commit -m initial &&
	git tag initial &&

	test_tick &&
	echo "Add extra line at the end" >>oops &&
	git commit -a -m added &&
	git tag added &&

	test_tick &&
	git mv oops spoo &&
	git commit -m rename1 &&
	git tag rename1 &&

	test_tick &&
	git checkout -b side initial &&
	git mv oops opos &&
	git commit -m rename2 &&
	git tag rename2
'

test_expect_success 'cherry-pick --nonsense' '

	pos=$(git rev-parse HEAD) &&
	git diff --exit-code HEAD &&
	test_must_fail git cherry-pick --nonsense 2>msg &&
	git diff --exit-code HEAD "$pos" &&
	test_i18ngrep '[Uu]sage:' msg
'

test_expect_success 'revert --nonsense' '

	pos=$(git rev-parse HEAD) &&
	git diff --exit-code HEAD &&
	test_must_fail git revert --nonsense 2>msg &&
	git diff --exit-code HEAD "$pos" &&
	test_i18ngrep '[Uu]sage:' msg
'

test_expect_success 'cherry-pick after renaming branch' '

	git checkout rename2 &&
	git cherry-pick added &&
	test $(git rev-parse HEAD^) = $(git rev-parse rename2) &&
	test -f opos &&
	grep "Add extra line at the end" opos &&
	git reflog -1 | grep cherry-pick

'

test_expect_success 'revert after renaming branch' '

	git checkout rename1 &&
	git revert added &&
	test $(git rev-parse HEAD^) = $(git rev-parse rename1) &&
	test -f spoo &&
	! grep "Add extra line at the end" spoo &&
	git reflog -1 | grep revert

'

test_expect_success 'cherry-pick on stat-dirty working tree' '
	git clone . copy &&
	(
		cd copy &&
		git checkout initial &&
		test-tool chmtime +40 oops &&
		git cherry-pick added
	)
'

test_expect_success 'revert forbidden on dirty working tree' '

	echo content >extra_file &&
	git add extra_file &&
	test_must_fail git revert HEAD 2>errors &&
	test_i18ngrep "your local changes would be overwritten by " errors

'

test_expect_success 'cherry-pick on unborn branch' '
	git checkout --orphan unborn &&
	git rm --cached -r . &&
	rm -rf * &&
	git cherry-pick initial &&
	git diff --quiet initial &&
	! test_cmp_rev initial HEAD
'

test_expect_success 'cherry-pick "-" to pick from previous branch' '
	git checkout unborn &&
	test_commit to-pick actual content &&
	git checkout master &&
	git cherry-pick - &&
	echo content >expect &&
	test_cmp expect actual
'

test_expect_success 'cherry-pick "-" is meaningless without checkout' '
	test_create_repo afresh &&
	(
		cd afresh &&
		test_commit one &&
		test_commit two &&
		test_commit three &&
		test_must_fail git cherry-pick -
	)
'

test_expect_success 'cherry-pick "-" works with arguments' '
	git checkout -b side-branch &&
	test_commit change actual change &&
	git checkout master &&
	git cherry-pick -s - &&
	echo "Signed-off-by: C O Mitter <committer@example.com>" >expect &&
	git cat-file commit HEAD | grep ^Signed-off-by: >signoff &&
	test_cmp expect signoff &&
	echo change >expect &&
	test_cmp expect actual
'

test_expect_success 'cherry-pick works with dirty renamed file' '
	test_commit to-rename &&
	git checkout -b unrelated &&
	test_commit unrelated &&
	git checkout @{-1} &&
	git mv to-rename.t renamed &&
	test_tick &&
	git commit -m renamed &&
	echo modified >renamed &&
	git cherry-pick refs/heads/unrelated >out &&
	test $(git rev-parse :0:renamed) = $(git rev-parse HEAD~2:to-rename.t) &&
	grep -q "^modified$" renamed
'

test_done
