require 'spec_helper'

describe PostActionsController do

  describe 'create' do
    it 'requires you to be logged in' do
      lambda { xhr :post, :create }.should raise_error(Discourse::NotLoggedIn)
    end

    describe 'logged in' do
      before do
        @user = log_in
        @post = Fabricate(:post, user: Fabricate(:coding_horror))
      end

      it 'raises an error when the id is missing' do
        lambda { xhr :post, :create, post_action_type_id: PostActionType.Types[:like] }.should raise_error(Discourse::InvalidParameters)
      end

      it 'raises an error when the post_action_type_id index is missing' do
        lambda { xhr :post, :create, id: @post.id }.should raise_error(Discourse::InvalidParameters)
      end
      
      it "fails when the user doesn't have permission to see the post" do
        Guardian.any_instance.expects(:can_see?).with(@post).returns(false)
        xhr :post, :create, id: @post.id, post_action_type_id: PostActionType.Types[:like]
        response.should be_forbidden
      end

      it "fails when the user doesn't have permission to perform that action" do
        Guardian.any_instance.expects(:post_can_act?).with(@post, :like).returns(false)
        xhr :post, :create, id: @post.id, post_action_type_id: PostActionType.Types[:like]
        response.should be_forbidden
      end

      it 'allows us to create an post action on a post' do
        PostAction.expects(:act).once.with(@user, @post, PostActionType.Types[:like], nil)
        xhr :post, :create, id: @post.id, post_action_type_id: PostActionType.Types[:like]
      end
    end

  end

  context 'destroy' do

    let(:post) { Fabricate(:post, user: Fabricate(:coding_horror)) }

    it 'requires you to be logged in' do
      lambda { xhr :delete, :destroy, id: post.id }.should raise_error(Discourse::NotLoggedIn)
    end

    context 'logged in' do
      let!(:user) { log_in }

      it 'raises an error when the post_action_type_id is missing' do
        lambda { xhr :delete, :destroy, id: post.id }.should raise_error(Discourse::InvalidParameters)
      end

      it "returns 404 when the post action type doesn't exist for that user" do
        xhr :delete, :destroy, id: post.id, post_action_type_id: 1
        response.code.should == '404'
      end

      context 'with a post_action record ' do
        let!(:post_action) { PostAction.create(user_id: user.id, post_id: post.id, post_action_type_id: 1)}

        it 'returns success' do
          xhr :delete, :destroy, id: post.id, post_action_type_id: 1
          response.should be_success
        end

        it 'deletes the action' do
          xhr :delete, :destroy, id: post.id, post_action_type_id: 1
          PostAction.exists?(user_id: user.id, post_id: post.id, post_action_type_id: 1, deleted_at: nil).should be_false
        end

        it 'ensures it can be deleted' do
          Guardian.any_instance.expects(:can_delete?).with(post_action).returns(false)
          xhr :delete, :destroy, id: post.id, post_action_type_id: 1
          response.should be_forbidden
        end
      end

    end

  end



  describe 'users' do

    let!(:post) { Fabricate(:post, user: log_in) }

    it 'raises an error without an id' do
      lambda {
        xhr :get, :users, post_action_type_id: PostActionType.Types[:like]
      }.should raise_error(Discourse::InvalidParameters)
    end

    it 'raises an error without a post action type' do
      lambda {
        xhr :get, :users, id: post.id
      }.should raise_error(Discourse::InvalidParameters)
    end

    it "fails when the user doesn't have permission to see the post" do
      Guardian.any_instance.expects(:can_see?).with(post).returns(false)
      xhr :get, :users, id: post.id, post_action_type_id: PostActionType.Types[:like]
      response.should be_forbidden
    end

    it 'raises an error when the post action type cannot be seen' do
      Guardian.any_instance.expects(:can_see_post_actors?).with(instance_of(Topic), PostActionType.Types[:like]).returns(false)
      xhr :get, :users, id: post.id, post_action_type_id: PostActionType.Types[:like]
      response.should be_forbidden
    end
      
    it 'succeeds' do
      xhr :get, :users, id: post.id, post_action_type_id: PostActionType.Types[:like]
      response.should be_success
    end

  end



end
