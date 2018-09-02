###
# Copyright (C) 2014-2017 Andrey Antukh <niwi@niwi.nz>
# Copyright (C) 2014-2017 Jesús Espino Garcia <jespinog@gmail.com>
# Copyright (C) 2014-2017 David Barragán Merino <bameda@dbarragan.com>
# Copyright (C) 2014-2017 Alejandro Alonso <alejandro.alonso@kaleidos.net>
# Copyright (C) 2014-2017 Juan Francisco Alcántara <juanfran.alcantara@kaleidos.net>
# Copyright (C) 2014-2017 Xavi Julian <xavier.julian@kaleidos.net>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#
# File: modules/related-stories.coffee
###

taiga = @.taiga
trim = @.taiga.trim
debounce = @.taiga.debounce

module = angular.module("showRelatedUserStories", [])


RelatedStoryRowDirective = ($repo, $compile, $confirm, $rootscope, $loading, $template, $translate, $emojis) ->
    templateView = $template.get("story/related-story-row.html", true)
    templateEdit = $template.get("story/related-story-row-edit.html", true)

    link = ($scope, $el, $attrs, $model) ->
        @childScope = $scope.$new()

        saveStory = debounce 2000, (story) ->
            story.subject = $el.find('input').val()

            currentLoading = $loading()
                .target($el.find('.story-name'))
                .start()

            promise = $repo.save(story)
            promise.then =>
                currentLoading.finish()
                $rootscope.$broadcast("related-us:update")

            promise.then null, =>
                currentLoading.finish()
                $el.find('input').val(story.subject)
                $confirm.notify("error")
            return promise

        renderEdit = (story) ->
            @childScope.$destroy()
            @childScope = $scope.$new()
            $el.off()
            $el.html($compile(templateEdit({story: story}))(childScope))

            $el.find(".story-name input").val(story.subject)

            $el.on "keyup", "input", (event) ->
                if event.keyCode == 13
                    saveStory($model.$modelValue).then ->
                        renderView($model.$modelValue)
                else if event.keyCode == 27
                    renderView($model.$modelValue)

            $el.on "click", ".save-story", (event) ->
                saveStory($model.$modelValue).then ->
                    renderView($model.$modelValue)

            $el.on "click", ".cancel-edit", (event) ->
                renderView($model.$modelValue)

        renderView = (story) ->
            perms = {
                modify_story: $scope.project.my_permissions.indexOf("modify_story") != -1
                delete_story: $scope.project.my_permissions.indexOf("delete_story") != -1
            }

            $el.html($compile(templateView({
                story: story,
                perms: perms,
                emojify: (text) -> $emojis.replaceEmojiNameByHtmlImgs(_.escape(text))
            }))($scope))

            $el.on "click", ".edit-story", ->
                renderEdit($model.$modelValue)
                $el.find('input').focus().select()

            $el.on "click", ".delete-story", (event) ->
                title = $translate.instant("TASK.TITLE_DELETE_ACTION")
                story = $model.$modelValue
                message = story.subject

                $confirm.askOnDelete(title, message).then (askResponse) ->
                    promise = $repo.remove(story)
                    promise.then ->
                        askResponse.finish()
                        $scope.$emit("related-stories:delete")

                    promise.then null, ->
                        askResponse.finish(false)
                        $confirm.notify("error")

        $scope.$watch $attrs.ngModel, (val) ->
            return if not val
            renderView(val)

        $scope.$on "related-stories:assigned-to-changed", ->
            $rootscope.$broadcast("related-stories:update")

        $scope.$on "related-stories:status-changed", ->
            $rootscope.$broadcast("related-stories:update")

        $scope.$on "$destroy", ->
            $el.off()

    return {link:link, require:"ngModel"}

module.directive("tgRelatedStoryRow", ["$tgRepo", "$compile", "$tgConfirm", "$rootScope", "$tgLoading",
                                      "$tgTemplate", "$translate", "$tgEmojis", RelatedStoryRowDirective])


RelatedStoryCreateFormDirective = ($repo, $compile, $confirm, $tgmodel, $loading, $analytics) ->
    newStory = {
        subject: ""
        assigned_to: null
    }

    link = ($scope, $el, $attrs) ->
        createStory = (story) ->
            story.subject = $el.find('input').val()
            story.assigned_to = $scope.newStory.assigned_to
            story.status = $scope.newStory.status
            $scope.newStory.status = $scope.project.default_story_status
            $scope.newStory.assigned_to = null

            currentLoading = $loading()
                .target($el.find('.story-name'))
                .start()

            promise = $repo.create("stories", story)
            promise.then ->
                $analytics.trackEvent("story", "create", "create story on userstory", 1)
                currentLoading.finish()
                $scope.$emit("related-stories:add")

            promise.then null, ->
                $el.find('input').val(story.subject)
                currentLoading.finish()
                $confirm.notify("error")

            return promise

        close = () ->
            $el.off()

            $scope.openNewRelatedStory = false

        reset = () ->
            newStory = {
                subject: ""
                assigned_to: null
            }

            newStory["status"] = $scope.project.default_story_status
            newStory["project"] = $scope.project.id
            newStory["user_story"] = $scope.us.id

            $scope.newStory = $tgmodel.make_model("stories", newStory)

        render = ->
            return if $scope.openNewRelatedStory

            $scope.openNewRelatedStory = true

            $el.on "keyup", "input", (event)->
                if event.keyCode == 13
                    createStory(newStory).then ->
                        reset()
                        $el.find('input').focus()

                else if event.keyCode == 27
                    $scope.$apply () -> close()

        $scope.save = () ->
            createStory(newStory).then ->
                close()

        taiga.bindOnce $scope, "us", reset

        $scope.$on "related-stories:show-form", ->
            $scope.$apply(render)

        $scope.$on "$destroy", ->
            $el.off()

    return {
        scope: true,
        link: link,
        templateUrl: 'story/related-story-create-form.html'
    }

module.directive("tgRelatedStoryCreateForm", ["$tgRepo", "$compile", "$tgConfirm", "$tgModel", "$tgLoading",
                                             "$tgAnalytics", RelatedStoryCreateFormDirective])


RelatedStoryCreateButtonDirective = ($repo, $compile, $confirm, $tgmodel, $template) ->
    template = $template.get("common/components/add-button.html", true)

    link = ($scope, $el, $attrs) ->
        $scope.$watch "project", (val) ->
            return if not val
            $el.off()
            if $scope.project.my_permissions.indexOf("add_story") != -1
                $el.html($compile(template())($scope))
            else
                $el.html("")

            $el.on "click", ".add-button", (event)->
                $scope.$emit("related-stories:add-new-clicked")

        $scope.$on "$destroy", ->
            $el.off()

    return {link: link}

module.directive("tgRelatedStoryCreateButton", ["$tgRepo", "$compile", "$tgConfirm", "$tgModel",
                                               "$tgTemplate", RelatedStoryCreateButtonDirective])


RelatedStoriesDirective = ($repo, $rs, $rootscope) ->
    link = ($scope, $el, $attrs) ->
        loadStories = ->
            return $rs.stories.list($scope.projectId, null, $scope.usId).then (stories) =>
                $scope.stories = _.sortBy(stories, (x) => [x.us_order, x.ref])
                return stories

        _isVisible = ->
            if $scope.project
                return $scope.project.my_permissions.indexOf("view_stories") != -1
            return false

        _isEditable = ->
            if $scope.project
                return $scope.project.my_permissions.indexOf("modify_story") != -1
            return false

        $scope.showRelatedStories = ->
            return _isVisible() && ( _isEditable() ||  $scope.stories?.length )

        $scope.$on "related-stories:add", ->
            loadStories().then ->
                $rootscope.$broadcast("related-stories:update")

        $scope.$on "related-stories:delete", ->
            loadStories().then ->
                $rootscope.$broadcast("related-stories:update")

        $scope.$on "related-stories:add-new-clicked", ->
            $scope.$broadcast("related-stories:show-form")

        taiga.bindOnce $scope, "us", (val) ->
            loadStories()

        $scope.$on "$destroy", ->
            $el.off()

    return {link: link}

module.directive("tgRelatedStories", ["$tgRepo", "$tgResources", "$rootScope", RelatedStoriesDirective])


RelatedStoryAssignedToInlineEditionDirective = ($repo, $rootscope, $translate, avatarService) ->
    template = _.template("""
    <img style="background-color: <%- bg %>" src="<%- imgurl %>" alt="<%- name %>"/>
    <figcaption><%- name %></figcaption>
    """)

    link = ($scope, $el, $attrs) ->
        updateRelatedStory = (story) ->
            ctx = {
                name: $translate.instant("COMMON.ASSIGNED_TO.NOT_ASSIGNED"),
            }

            member = $scope.usersById[story.assigned_to]

            avatar = avatarService.getAvatar(member)
            ctx.imgurl = avatar.url
            ctx.bg = avatar.bg

            if member
                ctx.name = member.full_name_display

            $el.find(".avatar").html(template(ctx))
            $el.find(".story-assignedto").attr('title', ctx.name)

        $ctrl = $el.controller()
        story = $scope.$eval($attrs.tgRelatedStoryAssignedToInlineEdition)
        notAutoSave = $scope.$eval($attrs.notAutoSave)
        autoSave = !notAutoSave

        $scope.$watch $attrs.tgRelatedStoryAssignedToInlineEdition, () ->
            story = $scope.$eval($attrs.tgRelatedStoryAssignedToInlineEdition)
            updateRelatedStory(story)

        updateRelatedStory(story)

        $el.on "click", ".story-assignedto", (event) ->
            $rootscope.$broadcast("assigned-to:add", story)

        taiga.bindOnce $scope, "project", (project) ->
            # If the user has not enough permissions the click events are unbinded
            if project.my_permissions.indexOf("modify_story") == -1
                $el.unbind("click")
                $el.find("a").addClass("not-clickable")

        $scope.$on "assigned-to:added", debounce 2000, (ctx, userId, updatedRelatedStory) =>
            if updatedRelatedStory.id == story.id
                updatedRelatedStory.assigned_to = userId
                if autoSave
                    $repo.save(updatedRelatedStory).then ->
                        $scope.$emit("related-stories:assigned-to-changed")
                updateRelatedStory(updatedRelatedStory)

        $scope.$on "$destroy", ->
            $el.off()

    return {link: link}

module.directive("tgRelatedStoryAssignedToInlineEdition", ["$tgRepo", "$rootScope", "$translate", "tgAvatarService",
                                                          RelatedStoryAssignedToInlineEditionDirective])
