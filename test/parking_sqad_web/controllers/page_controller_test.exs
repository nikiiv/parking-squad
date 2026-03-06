defmodule ParkingSqadWeb.PageControllerTest do
  use ParkingSqadWeb.ConnCase

  test "unauthenticated user is redirected to login", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == "/login"
  end

  test "login page renders", %{conn: conn} do
    conn = get(conn, ~p"/login")
    assert html_response(conn, 200) =~ "Parking Squad"
  end

  test "register page renders", %{conn: conn} do
    conn = get(conn, ~p"/register")
    assert html_response(conn, 200) =~ "Create your account"
  end
end
