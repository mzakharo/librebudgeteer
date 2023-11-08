import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/filter.dart';
import '../providers/labels.dart';

// Used in DashboardListHeader.

class LabelFilterDropdown extends StatelessWidget {
  Widget buildFilterLabelCard(Color? color, String title) {
    return Row(
      children: <Widget>[
        CircleAvatar(
          maxRadius: 10,
          backgroundColor: color,
        ),
        const SizedBox(width: 10),
        //Text(title),

        Container(
            //Here you can control the width of your container ..
            //when text exceeds it will be trancated via elipses...
            width: 250.0,
            child: Text(
              title,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            )),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final labels = Provider.of<Labels>(context).items;
    final filterData = Provider.of<Filter>(context);

    return DropdownButton<String>(
      icon: const Icon(Icons.filter_list),
      value: filterData.labelId,
      // So it's easy to tell when the list is actually filtering.
      underline: Container(
        height: filterData.labelId == null ? 1 : 2,
        color: Colors.grey[300],
      ),
      items: [
        DropdownMenuItem(
          value: null,
          child: buildFilterLabelCard(
            Colors.transparent,
            'All',
          ),
        ),
        ...labels.map(
          (label) {
            var amt = label.getLabelAmountTotal(context).toInt();
            String extra = (amt != 0) ? " = ${amt}" : "";
            return DropdownMenuItem(
              value: label.id,
              child: buildFilterLabelCard(
                label.color,
                '${label.title.substring(0, (label.title.length < 20) ? label.title.length : 20)}${extra}',
              ),
            );
          },
        ).toList()
      ],
      onChanged: (newFilterId) {
        filterData.labelId = newFilterId;
      },
    );
  }
}
