require "test_helper"

class TodosControllerTest < ActionDispatch::IntegrationTest
  setup do
    @todo = todos(:one)
  end

  test "should get index" do
    get todos_url
    assert_response :success
  end

  test "should get new" do
    get new_todo_url
    assert_response :success
  end

  test "should create todo" do
    assert_difference("Todo.count") do
      post todos_url, params: { todo: { description: @todo.description } }
    end

    assert_redirected_to todo_url(Todo.last)
  end

  test "should show todo" do
    get todo_url(@todo)
    assert_response :success
  end

  test "should get edit" do
    get edit_todo_url(@todo)
    assert_response :success
  end

  test "should update todo" do
    patch todo_url(@todo), params: { todo: { description: @todo.description } }
    assert_redirected_to todo_url(@todo)
  end

  test "toggle_priority flips high_priority and responds with a Turbo Stream" do
    assert_equal false, @todo.high_priority

    patch toggle_priority_todo_url(@todo),
          headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_equal true, @todo.reload.high_priority
    assert_match(/turbo-stream action="replace"/, response.body)
    assert_match(/target="#{ActionView::RecordIdentifier.dom_id(@todo)}"/, response.body)
  end

  test "should destroy todo" do
    assert_difference("Todo.count", -1) do
      delete todo_url(@todo)
    end

    assert_redirected_to todos_url
  end
end
