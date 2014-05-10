BZR SCM LWRP
============

This cookbook provides a LWRP for easily creating and managing bzr branches.

**This cookbook has been created by Akretion to work with OpenERP. Hence
some choices are made to support our OpenERP workflow rather than just
work with bzr with Chef in general although there is no dependency
on OpenERP.**

Specially, we provides hacks to support stacked branches or bootstraping
the src tree with a tarball. This is because OpenERP bzr code isn't
fast to checkout from Launchpad...

This Cookbook is heavly inspired by the git resource and provider by GetChef
https://github.com/opscode/chef/blob/master/lib/chef/resource/git.rb
https://github.com/opscode/chef/blob/master/lib/chef/provider/git.rb

Akretion open sourced this recipe in the hope in can be useful to somebody.
If you wish to contribute, we may consider making it a generic bzr provider.

Until this eventually becomes a generic bzr provider, we prefer call the
resource "ak_bzr_branch" rather than say just "bzr" so it won't conflict
with another possibly more generic bzr provider.


Usage
-----

example of ak_bzr_branch resource:

```ruby
ak_bzr_branch "#{node[:openerp][:home]}/prod/pt-br-localiz" do
  repo "lp:openerp.pt-br-localiz#HEAD"
  action :sync 
  user some_user
  group some_groups
  notifies :run, resources(:execute => "some_service")
end
```

### LWRP Attributes

the same as the git resource http://docs.opscode.com/resource_git.html

<table>
  <tr>
    <th>Attribute</th>
    <th>Description</th>
    <th>Example</th>
    <th>Default</th>
  </tr>
  <tr>
    <td>parent</td>
    <td>see bzr</td>
    <td></td>
    <td></td>
  </tr>
  <tr>
    <td>push_location</td>
    <td>see bzr</td>
    <td></td>
    <td></td>
  </tr>
  <tr>
    <td>stacked_on_location</td>
    <td>see bzr</td>
    <td></td>
    <td></td>
  </tr>
  <tr>
    <td>public_location</td>
    <td>see bzr</td>
    <td></td>
    <td></td>
  </tr>
  <tr>
    <td>tarball</td>
    <td>A src tarball to bootstrap the src tree before updating it to the desired revision</td>
    <td></td>
    <td></td>
  </tr>
  </tr>
</table>


Installation
------------
If you're using [berkshelf](https://github.com/RiotGames/berkshelf), add `swap` to your `Berksfile`:

```ruby
cookbook 'ak-bzr'
```

Otherwise, install the cookbook from the community site:

    knife cookbook site install ak-bzr

Have any other cookbooks depend on this cookbook by adding it to the `metadata.rb`:

```ruby
depends 'ak-bzr'
```

Now you can use the LWRP in your cookbook!


Contributing
------------
1. Fork the project
2. Create a feature branch corresponding to you change
3. Commit and test thoroughly
4. Create a Pull Request on github
    - ensure you add a detailed description of your changes


License and Authors
-------------------
- Author:: Raphaël Valyi (raphael.valyi@akretion.com), Sebastien Beau (sebastien.beau@akretion.com)

```text
Copyright 2013-2014 Akretion LTDA

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
