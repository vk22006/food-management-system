from salesforce import get_menu, get_order


def get_menu_tool():
    """Get the currently available QuickBite menu from Salesforce."""
    return get_menu()


def get_order_tool(order_name):
    """Get a QuickBite order using its order number, such as ORD-00006."""
    return get_order(order_name)