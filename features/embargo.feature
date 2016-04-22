Feature: Embargo Date and Time on an Article (User Story: https://dev.sourcefabric.org/browse/SD-3036)

  Background: Setup data required to test the Embargo feature
    Given the "validators"
    """
    [{"schema": {}, "type": "text", "act": "publish", "_id": "publish_text"},
     {"schema": {}, "type": "text", "act": "correct", "_id": "correct_text"},
     {"schema": {}, "type": "text", "act": "kill",    "_id": "kill_text"}]
    """
    And "desks"
    """
    [{"name": "Sports", "content_expiry": "4320"}]
    """
    And "products"
      """
      [{
        "_id": "1", "name":"prod-1", "codes":"abc,xyz"
      }]
      """
    And "subscribers"
    """
    [{"_id": "123", "name":"Wire Subscriber","media_type":"media", "subscriber_type": "wire", "sequence_num_settings":{"min" : 1, "max" : 10}, "email": "test@test.com",
      "products": ["1"],
      "destinations":[{"name":"email","format": "nitf", "delivery_type":"email","config":{"recipients":"test@test.com"}}]},
     {"_id": "321", "name":"Digital Subscriber","media_type":"media", "subscriber_type": "digital", "sequence_num_settings":{"min" : 1, "max" : 10}, "email": "test@test.com",
      "products": ["1"],
      "destinations":[{"name":"email","format": "nitf", "delivery_type":"email","config":{"recipients":"test@test.com"}}]}
    ]
    """
    And "archive"
    """
    [{"guid": "123", "type": "text", "slugline": "text with embargo", "headline": "test", "_current_version": 1, "state": "fetched", "anpa_take_key": "Take",
      "unique_id": "123456", "unique_name": "#text_with_embargo", "subject":[{"qcode": "17004000", "name": "Statistics"}], "body_html": "Test Document body",
      "task": {"desk": "#desks._id#", "stage": "#desks.incoming_stage#", "user": "#CONTEXT_USER_ID#"}}]
    """

  @auth
  Scenario: Create a Text Article with Embargo
    When we post to "/archive" with success
    """
    [{"guid": "text-article-with-embargo", "type": "text", "embargo": "2020-02-13T22:46:19.000Z"}]
    """
    When we get "/archive"
      Then we get list with 2 items
      """
      {
        "_items":
          [
            {"embargo":  "2020-02-13T22:46:19+0000",
             "schedule_settings":  {"utc_embargo": "2020-02-13T22:46:19+0000"}
            }
          ]
      }
      """
    Then we get "embargo" in "/archive/text-article-with-embargo"

  @auth
  Scenario: Create a Text Article with Embargo an time zone
    When we post to "/archive" with success
    """
    [{"guid": "text-article-with-embargo",
      "type": "text",
      "embargo": "2020-02-13T22:46:19.000Z",
      "schedule_settings":{"time_zone": "Australia/Sydney"}}]
    """
    When we get "/archive"
    Then we get list with 2 items
    """
    {
      "_items":
        [
          {"embargo":  "2020-02-13T22:46:19+0000",
           "schedule_settings":  {"utc_embargo": "2020-02-13T11:46:19+0000"}
          }
        ]
    }
    """
    Then we get "embargo" in "/archive/text-article-with-embargo"

  @auth
  Scenario: Update a Text Article with Embargo and timezone
    When we patch "/archive/123"
    """
    {"embargo": "2020-02-13T22:46:19+0000", "headline": "here comes the embargo"}
    """
    Then we get response code 200
    When we get "/archive/123"
    Then we get existing resource
    """
    {"embargo":  "2020-02-13T22:46:19+0000",
     "schedule_settings":  {"utc_embargo": "2020-02-13T22:46:19+0000"}
    }
    """
    When we patch "/archive/123"
    """
    {"schedule_settings": {"time_zone": "Australia/Sydney"}}
    """
    Then we get response code 200
    When we get "/archive/123"
    Then we get existing resource
    """
    {"embargo":  "2020-02-13T22:46:19+0000",
     "schedule_settings":  {"utc_embargo": "2020-02-13T11:46:19+0000"}
    }
    """
    When we patch "/archive/123"
    """
    {"embargo": "2020-03-13T22:46:19+0000"}
    """
    Then we get response code 200
    When we get "/archive/123"
    Then we get existing resource
    """
    {"embargo":  "2020-03-13T22:46:19+0000",
     "schedule_settings":  {"utc_embargo": "2020-03-13T11:46:19+0000"}
    }
    """
    When we patch "/archive/123"
    """
    {"schedule_settings": {"time_zone": null}}
    """
    Then we get response code 200
    When we get "/archive/123"
    Then we get existing resource
    """
    {"embargo":  "2020-03-13T22:46:19+0000",
     "schedule_settings":  {"utc_embargo": "2020-03-13T22:46:19+0000"}
    }
    """
   When we patch "/archive/123"
    """
    {"embargo": null}
    """
    Then we get response code 200
    When we get "/archive/123"
    Then we get existing resource
    """
    {"embargo":  null,
     "schedule_settings":  {"utc_embargo": null}
    }
    """

  @auth
  Scenario: An article with Embargo always goes to Wire Subscribers irrespective of publish action until embargo lapses
    When we patch "/archive/123"
    """
    {"embargo": "#DATE+2#"}
    """
    And we publish "#archive._id#" with "publish" type and "published" state
    Then we get OK response
    And we get existing resource
    """
    {"_current_version": 3, "state": "published"}
    """
    And we get expiry for schedule and embargo content 4320 minutes after "#archive_publish.embargo#"
    And we check if article has Embargo and Ed. Note of the article has embargo indication
    When we get "/published"
    Then we check if article has Embargo and Ed. Note of the article has embargo indication
    When we enqueue published
    When we get "/publish_queue"
    Then we get list with 1 items
    """
    {"_items": [{"subscriber_id": "123", "publishing_action": "published", "content_type": "text", "destination":{"name":"email"}}]}
    """
    When we publish "#archive._id#" with "correct" type and "corrected" state
    """
    {"headline": "corrected article"}
    """
    Then we get OK response
    When we enqueue published
    When we get "/publish_queue"
    Then we get list with 2 items
    """
    {"_items": [{"subscriber_id": "123", "publishing_action": "published", "content_type": "text", "destination":{"name":"email"}},
                {"subscriber_id": "123", "publishing_action": "corrected", "content_type": "text", "destination":{"name":"email"}}]}
    """
    When we publish "#archive._id#" with "kill" type and "killed" state
    """
    {"abstract": "killed"}
    """
    Then we get OK response
    When we enqueue published
    When we get "/publish_queue"
    Then we get list with 3 items
    """
    {"_items": [{"subscriber_id": "123", "publishing_action": "published", "content_type": "text", "destination":{"name":"email"}},
                {"subscriber_id": "123", "publishing_action": "corrected", "content_type": "text", "destination":{"name":"email"}},
                {"subscriber_id": "123", "publishing_action": "killed", "content_type": "text", "destination":{"name":"email"}}]}
    """

  @auth
  Scenario: Publish an article with Embargo and validate metadata
    When we patch "/archive/123"
    """
    {"embargo": "#DATE+2#"}
    """
    And we publish "#archive._id#" with "publish" type and "published" state
    Then we get OK response
    And we get existing resource
    """
    {"_current_version": 3, "state": "published", "task":{"desk": "#desks._id#", "stage": "#desks.incoming_stage#"}}
    """
    And we get expiry for schedule and embargo content 4320 minutes after "#archive_publish.embargo#"
    And we check if article has Embargo and Ed. Note of the article has embargo indication
    When we get "/published"
    Then we get existing resource
    """
    {"_items" : [{"_id": "123", "guid": "123", "headline": "test", "_current_version": 3, "state": "published",
      "task": {"desk": "#desks._id#", "stage": "#desks.incoming_stage#", "user": "#CONTEXT_USER_ID#"}}]}
    """
    And we check if article has Embargo and Ed. Note of the article has embargo indication
    When we enqueue published
    When we get "/publish_queue"
    Then we get list with 1 items
    """
    {"_items": [{"subscriber_id": "123", "publishing_action": "published", "content_type": "text", "destination":{"name":"email"}}]}
    """
    When we enqueue published
    And we publish "#archive._id#" with "correct" type and "corrected" state
    Then we get OK response
    When we enqueue published
    When we get "/publish_queue"
    Then we get list with 2 items
    """
    {"_items": [{"subscriber_id": "123", "publishing_action": "published", "content_type": "text", "destination":{"name":"email"}},
                {"subscriber_id": "123", "publishing_action": "corrected", "content_type": "text", "destination":{"name":"email"}}]}
    """
    When we get "/archive/#archive.123.take_package#"
    Then we check if article has Embargo and Ed. Note of the article has embargo indication
    When we get "/published"
    Then we validate the published item expiry to be after publish expiry set in desk settings 4320

  @auth
  Scenario: Publish an article with Embargo and embargo lapses
    When we patch "/archive/123"
    """
    {"embargo": "#DATE+2#"}
    """
    And we publish "#archive._id#" with "publish" type and "published" state
    Then we get OK response
    And we get existing resource
    """
    {"_current_version": 3, "state": "published", "task":{"desk": "#desks._id#", "stage": "#desks.incoming_stage#"}}
    """
    And we get expiry for schedule and embargo content 4320 minutes after "#archive_publish.embargo#"
    And we check if article has Embargo and Ed. Note of the article has embargo indication
    When we get "/published"
    Then we get existing resource
    """
    {"_items" : [{"_id": "123", "guid": "123", "headline": "test", "_current_version": 3, "state": "published",
      "task": {"desk": "#desks._id#", "stage": "#desks.incoming_stage#", "user": "#CONTEXT_USER_ID#"}}]}
    """
    And we check if article has Embargo and Ed. Note of the article has embargo indication
    When we enqueue published
    When we get "/publish_queue"
    Then we get list with 1 items
    """
    {"_items": [{"subscriber_id": "123", "publishing_action": "published", "content_type": "text", "destination":{"name":"email"}}]}
    """
    When embargo lapses for "#archive._id#"
    And we publish "#archive._id#" with "correct" type and "corrected" state
    Then we get OK response
    When we enqueue published
    When we get "/publish_queue"
    Then we get list with 2 items
    """
    {"_items": [{"subscriber_id": "123", "publishing_action": "published", "content_type": "text", "destination":{"name":"email"}},
                {"subscriber_id": "123", "publishing_action": "corrected", "content_type": "text", "destination":{"name":"email"}}]}
    """
    When we get "/archive/#archive.123.take_package#"
    """
    {"ednote": ""}
    """
    When we get "/published"
    Then we validate the published item expiry to be after publish expiry set in desk settings 4320

  @auth
  Scenario: Publish an article with Embargo and change embargo in correction
    When we patch "/archive/123"
    """
    {"embargo": "#DATE+2#"}
    """
    And we publish "#archive._id#" with "publish" type and "published" state
    Then we get OK response
    And we get existing resource
    """
    {"_current_version": 3, "state": "published", "task":{"desk": "#desks._id#", "stage": "#desks.incoming_stage#"}}
    """
    And we get expiry for schedule and embargo content 4320 minutes after "#archive_publish.embargo#"
    And we check if article has Embargo and Ed. Note of the article has embargo indication
    When we get "/published"
    Then we get existing resource
    """
    {"_items" : [{"_id": "123", "guid": "123", "headline": "test", "_current_version": 3, "state": "published",
      "task": {"desk": "#desks._id#", "stage": "#desks.incoming_stage#", "user": "#CONTEXT_USER_ID#"}}]}
    """
    And we check if article has Embargo and Ed. Note of the article has embargo indication
    When we enqueue published
    When we get "/publish_queue"
    Then we get list with 1 items
    """
    {"_items": [{"subscriber_id": "123", "publishing_action": "published", "content_type": "text", "destination":{"name":"email"}}]}
    """
    When we publish "#archive._id#" with "correct" type and "corrected" state
    """
    {"embargo": "#DATE+3#"}
    """
    Then we get OK response
    When we enqueue published
    When we get "/publish_queue"
    Then we get list with 2 items
    """
    {"_items": [{"subscriber_id": "123", "publishing_action": "published", "content_type": "text", "destination":{"name":"email"}},
                {"subscriber_id": "123", "publishing_action": "corrected", "content_type": "text", "destination":{"name":"email"}}]}
    """
    When we get "/published"
    Then we validate the published item expiry to be after publish expiry set in desk settings 4320
    And we check if article has Embargo and Ed. Note of the article has embargo indication
    When we publish "#archive._id#" with "correct" type and "corrected" state
    """
    {"embargo": null}
    """
    Then we get OK response
    When we enqueue published
    When we get "/published"
    Then we validate the published item expiry to be after publish expiry set in desk settings 4320
    When we get "/archive/#archive.123.take_package#"
    """
    {"ednote": ""}
    """

  @auth
  Scenario: Creating/Updating an item without a future Embargo should fail
    When we post to "/archive"
    """
    [{"guid": "text-article-with-embargo", "type": "text", "embargo": "#DATE-2#"}]
    """
    Then we get error 400
    """
    {"_message": "Embargo cannot be earlier than now"}
    """
    When we patch "/archive/123"
    """
    {"embargo": "#DATE-1#"}
    """
    Then we get error 400
    """
    {"_issues": {"validator exception": "400: Embargo cannot be earlier than now"}}
    """

  @auth
  Scenario: Creating/Updating a Package with Embargo should fail
    Given "desks"
    """
    [{"name": "test desk"}]
    """
    When we post to "/archive"
    """
    [{
    	"guid": "text-article-with-embargo",
    	"type": "composite",
    	"embargo": "#DATE+1#",
        "task": {"user": "#user._id#", "desk": "#desks._id#"}
    }]
    """
    Then we get error 400
    """
    {"_message": "A Package doesn't support Embargo"}
    """
    When we post to "/archive" with success
    """
    {
        "groups": [
            {"id": "root", "refs": [{"idRef": "main"}], "role": "grpRole:NEP"},
            {"id": "main", "refs": [{"residRef": "123"}], "role": "grpRole:Main"}
        ],
        "guid": "tag:example.com,0000:newsml_BRE9A605",
        "type": "composite",
        "task": {"user": "#user._id#", "desk": "#desks._id#"}
    }
    """
    And we patch "/archive/tag:example.com,0000:newsml_BRE9A605"
    """
    {"embargo": "#DATE+1#"}
    """
    Then we get error 400
    """
    {"_issues": {"validator exception": "400: A Package doesn't support Embargo"}}
    """

  @auth
  Scenario: A package can't have Embargo Item(s)
    When we patch "/archive/123"
    """
    {"embargo": "#DATE+2#"}
    """
    And we post to "/archive"
    """
    {
        "groups": [
            {"id": "root", "refs": [{"idRef": "main"}], "role": "grpRole:NEP"},
            {"id": "main", "refs": [{"residRef": "123"}], "role": "grpRole:Main"}
        ],
        "guid": "tag:example.com,0000:newsml_BRE9A605",
        "type": "composite",
        "task": {"user": "#user._id#", "desk": "#desks._id#"}
    }
    """
    Then we get error 400
    """
    {"_message": "Package can't have item which has embargo. Slugline/Unique Name of the item having embargo: text with embargo/#text_with_embargo"}
    """

  @auth
  Scenario: An article can't have both Publish Schedule and Embargo
    When we post to "/archive"
    """
    [{"guid": "text-article-with-embargo", "type": "text", "publish_schedule": "#DATE+1#", "embargo": "#DATE+1#"}]
    """
    Then we get error 400
    """
    {"_message": "An item can't have both Publish Schedule and Embargo"}
    """
    When we patch "/archive/123"
    """
    {"publish_schedule": "#DATE+1#", "embargo": "#DATE+1#"}
    """
    Then we get error 400
    """
    {"_issues": {"validator exception": "400: An item can't have both Publish Schedule and Embargo"}}
    """

  @auth
  Scenario: Can't set an Embargo after publishing
    When we publish "#archive._id#" with "publish" type and "published" state
    Then we get OK response
    And we get existing resource
    """
    {"_current_version": 2, "state": "published", "task":{"desk": "#desks._id#", "stage": "#desks.incoming_stage#"}}
    """
    When we get "/published"
    Then we get existing resource
    """
    {"_items" : [{"_id": "123", "guid": "123", "headline": "test", "_current_version": 2, "state": "published",
      "task": {"desk": "#desks._id#", "stage": "#desks.incoming_stage#", "user": "#CONTEXT_USER_ID#"}}]}
    """
    When we publish "#archive._id#" with "correct" type and "corrected" state
    """
    {"embargo": "#DATE+1#"}
    """
    Then we get error 400
    """
    {"_issues": {"validator exception": "400: Embargo can't be set after publishing"}}
    """

  @auth
  Scenario: Cannot set Embargo for a Take
    When we post to "archive/123/link"
    """
    [{}]
    """
    Then we get next take as "TAKE2"
    """
    {"_id": "#TAKE2#", "type": "text", "headline": "test", "anpa_take_key": "Take=2",
     "state": "draft", "original_creator": "#CONTEXT_USER_ID#",
     "takes": {"_id": "#TAKE_PACKAGE#", "package_type": "takes", "type": "composite"},
     "linked_in_packages": [{"package_type" : "takes","package" : "#TAKE_PACKAGE#"}]
    }
    """
    When we patch "/archive/123"
    """
    {"embargo": "#DATE+1#"}
    """
    Then we get error 400
    """
    {"_issues": {"validator exception": "400: Takes doesn't support Embargo"}}
    """

  @auth
  Scenario: Cannot create a Take for an article which has Embargo
    When we patch "/archive/123"
    """
    {"embargo": "#DATE+1#"}
    """
    And we post to "archive/123/link"
    """
    [{}]
    """
    Then we get error 400
    """
    {"_message": "Takes can't be created for an Item having Embargo"}
    """

  @auth
  Scenario: Cannot rewrite an article which has Embargo
    When we patch "/archive/123"
    """
    {"embargo": "#DATE+1#"}
    """
    And we publish "#archive._id#" with "publish" type and "published" state
    Then we get OK response
    And we get existing resource
    """
    {"_current_version": 3, "state": "published", "task":{"desk": "#desks._id#", "stage": "#desks.incoming_stage#"}}
    """
    When we get "/published"
    Then we get existing resource
    """
    {"_items" : [{"_id": "123", "guid": "123", "headline": "test", "_current_version": 3, "state": "published",
      "task": {"desk": "#desks._id#", "stage": "#desks.incoming_stage#", "user": "#CONTEXT_USER_ID#"}}]}
    """
    When we rewrite "123"
    """
    {"desk_id": "#desks._id#"}
    """
    Then we get error 400
    """
    {"_message": "Rewrite of an Item having embargo isn't possible"}
    """

  @auth
  Scenario: Embargo shouldn't be copied while Duplicating an Embargoed Article
    When we patch "/archive/123"
    """
    {"embargo": "#DATE+2#", "headline": "here comes the embargo"}
    """
    Then we get response code 200
    When we post to "/archive/123/duplicate" with success
    """
    {"desk": "#desks._id#"}
    """
    And we get "/archive/#duplicate._id#"
    Then there is no "embargo" in response

  @auth
  Scenario: Embargo shouldn't be copied while Copying an Embargoed Article
    When we post to "/archive" with success
    """
    [{"type":"text", "headline": "test1", "state": "draft", "guid": "text-article-with-embargo", "embargo": "#DATE+2#"}]
    """
    When we post to "/archive/text-article-with-embargo/copy" with success
    """
    {}
    """
    And we get "/archive/#copy._id#"
    Then there is no "embargo" in response

  @auth
  Scenario: Deschedule an article then embargo the same article
    When we patch "/archive/123"
    """
    {"publish_schedule": "#DATE+1#"}
    """
    Then we get response code 200
    When we publish "123" with "publish" type and "published" state
    Then we get OK response
    And we get existing resource
    """
    {"state": "scheduled", "_id": "123"}
    """
    When we get "/archive/#archive.123.take_package#"
    Then we get existing resource
    """
    {"state": "scheduled", "_id": "#archive.123.take_package#"}
    """
    When we get "/published"
    Then we get list with 2 items
    """
    {"_items": [
      {"state": "scheduled", "_id": "123", "type": "text"},
      {"state": "scheduled", "_id": "#archive.123.take_package#", "type": "composite"}
    ]}
    """
    When we enqueue published
    When we get "/publish_queue"
    Then we get list with 0 items
    When we patch "/archive/123"
    """
    {"publish_schedule": null}
    """
    Then we get OK response
    When we get "/archive/123"
    Then we get existing resource
    """
    {"state": "in_progress", "_id": "123", "publish_schedule": "__none__"}
    """
    When we get "/archive/#TAKE_PACKAGE#"
    Then we get error 404
    When we get "/published"
    Then we get list with 0 items
    When we get "/publish_queue"
    Then we get list with 0 items
    When we patch "/archive/123"
    """
    {"embargo": "#DATE+1#"}
    """
    Then we get OK response
    When we publish "123" with "publish" type and "published" state
    Then we get OK response
    And we get expiry for schedule and embargo content 4320 minutes after "#archive_publish.embargo#"
    And we check if article has Embargo and Ed. Note of the article has embargo indication
    When we get "/published"
    Then we check if article has Embargo and Ed. Note of the article has embargo indication
    When we enqueue published
    When we get "/publish_queue"
    Then we get list with 1 items
    """
    {"_items": [{"subscriber_id": "123", "publishing_action": "published", "content_type": "text", "destination":{"name":"email"}}]}
    """
