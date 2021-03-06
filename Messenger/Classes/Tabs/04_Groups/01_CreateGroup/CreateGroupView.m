//
// Copyright (c) 2016 Related Code - http://relatedcode.com
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "CreateGroupView.h"

//-------------------------------------------------------------------------------------------------------------------------------------------------
@interface CreateGroupView()
{
	NSString *linkPicture;

	NSArray *blockerIds;
	NSMutableArray *numbers;

	RLMResults *dbusers;
	NSMutableArray *sections;
	NSMutableArray *selection;
}

@property (strong, nonatomic) IBOutlet UIImageView *imageGroup;
@property (strong, nonatomic) IBOutlet UITextField *fieldName;
@property (strong, nonatomic) IBOutlet UISearchBar *searchBar;
@property (strong, nonatomic) IBOutlet UITableView *tableView;

@end
//-------------------------------------------------------------------------------------------------------------------------------------------------

@implementation CreateGroupView

@synthesize imageGroup, fieldName, searchBar;

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)viewDidLoad
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	[super viewDidLoad];
	self.title = @"Create Group";
	//---------------------------------------------------------------------------------------------------------------------------------------------
	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self
																						  action:@selector(actionCancel)];
	//---------------------------------------------------------------------------------------------------------------------------------------------
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self
																						   action:@selector(actionDone)];
	//---------------------------------------------------------------------------------------------------------------------------------------------
	UITapGestureRecognizer *gestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
	[self.tableView addGestureRecognizer:gestureRecognizer];
	gestureRecognizer.cancelsTouchesInView = NO;
	//---------------------------------------------------------------------------------------------------------------------------------------------
	self.tableView.tableFooterView = [[UIView alloc] init];
	//---------------------------------------------------------------------------------------------------------------------------------------------
	blockerIds = [Blocked blockerIds];
	numbers = [[NSMutableArray alloc] init];
	//---------------------------------------------------------------------------------------------------------------------------------------------
	selection = [[NSMutableArray alloc] init];
	//---------------------------------------------------------------------------------------------------------------------------------------------
	[self loadContacts];
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)viewDidAppear:(BOOL)animated
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	[super viewDidAppear:animated];
	[fieldName becomeFirstResponder];
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)viewWillDisappear:(BOOL)animated
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	[super viewWillDisappear:animated];
	[self dismissKeyboard];
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)dismissKeyboard
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	[self.view endEditing:YES];
}

#pragma mark - Realm methods

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)loadContacts
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	[numbers removeAllObjects];
	//---------------------------------------------------------------------------------------------------------------------------------------------
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"isDeleted == NO"];
	RLMResults *dbcontacts = [DBContact objectsWithPredicate:predicate];
	//---------------------------------------------------------------------------------------------------------------------------------------------
	for (DBContact *dbcontact in dbcontacts)
	{
		for (NSString *number in [dbcontact.numbers componentsSeparatedByString:@","])
			[numbers addObject:number];
	}
	//---------------------------------------------------------------------------------------------------------------------------------------------
	[self loadUsers];
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)loadUsers
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	NSString *text = searchBar.text;
	//---------------------------------------------------------------------------------------------------------------------------------------------
	NSString *format = @"objectId != %@ AND NOT objectId IN %@ AND phone IN %@ AND fullname CONTAINS[c] %@";
	NSPredicate *predicate = [NSPredicate predicateWithFormat:format, [FUser currentId], blockerIds, numbers, text];
	//---------------------------------------------------------------------------------------------------------------------------------------------
	dbusers = [[DBUser objectsWithPredicate:predicate] sortedResultsUsingKeyPath:FUSER_FULLNAME ascending:YES];
	//---------------------------------------------------------------------------------------------------------------------------------------------
	[self refreshTableView];
}

#pragma mark - Refresh methods

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)refreshTableView
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	[self setObjects];
	[self.tableView reloadData];
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)setObjects
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	if (sections != nil) [sections removeAllObjects];
	//---------------------------------------------------------------------------------------------------------------------------------------------
	NSInteger sectionTitlesCount = [[[UILocalizedIndexedCollation currentCollation] sectionTitles] count];
	sections = [[NSMutableArray alloc] initWithCapacity:sectionTitlesCount];
	//---------------------------------------------------------------------------------------------------------------------------------------------
	for (NSUInteger i=0; i<sectionTitlesCount; i++)
	{
		[sections addObject:[NSMutableArray array]];
	}
	//---------------------------------------------------------------------------------------------------------------------------------------------
	for (DBUser *dbuser in dbusers)
	{
		NSInteger section = [[UILocalizedIndexedCollation currentCollation] sectionForObject:dbuser collationStringSelector:@selector(fullname)];
		[sections[section] addObject:dbuser];
	}
}

#pragma mark - Backend actions

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)createGroup
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	[ProgressHUD show:nil Interaction:NO];
	//---------------------------------------------------------------------------------------------------------------------------------------------
	FObject *object = [FObject objectWithPath:FGROUP_PATH];
	object[FGROUP_USERID] = [FUser currentId];
	object[FGROUP_NAME] = fieldName.text;
	if (linkPicture != nil) object[FGROUP_PICTURE] = linkPicture;
	object[FGROUP_MEMBERS] = selection;
	object[FGROUP_ISDELETED] = @NO;
	//---------------------------------------------------------------------------------------------------------------------------------------------
	[object saveInBackground:^(NSError *error)
	{
		if (error == nil)
		{
			[ProgressHUD dismiss];
			[Group membersAdded:object members:selection];
			//-------------------------------------------------------------------------------------------------------------------------------------
			[self dismissViewControllerAnimated:YES completion:nil];
		}
		else [ProgressHUD showError:@"Network error."];
	}];
}

#pragma mark - User actions

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)actionCancel
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	[self dismissViewControllerAnimated:YES completion:nil];
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)actionDone
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	NSString *name = fieldName.text;
	//---------------------------------------------------------------------------------------------------------------------------------------------
	if ([name length] == 0)		{ [ProgressHUD showError:@"Group name must be set."]; return; }
	if ([selection count] == 0)	{ [ProgressHUD showError:@"Please select some users."]; return; }
	//---------------------------------------------------------------------------------------------------------------------------------------------
	if ([Connection isReachable] == NO) { [ProgressHUD showError:@"No network connection."]; return; }
	//---------------------------------------------------------------------------------------------------------------------------------------------
	[selection addObject:[FUser currentId]];
	//---------------------------------------------------------------------------------------------------------------------------------------------
	[self createGroup];
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (IBAction)actionImage:(id)sender
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	[self dismissKeyboard];
	//---------------------------------------------------------------------------------------------------------------------------------------------
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
	//---------------------------------------------------------------------------------------------------------------------------------------------
	[alert addAction:[UIAlertAction actionWithTitle:@"Open Camera" style:UIAlertActionStyleDefault
											handler:^(UIAlertAction *action) { PresentPhotoCamera(self, YES); }]];
	[alert addAction:[UIAlertAction actionWithTitle:@"Photo Library" style:UIAlertActionStyleDefault
											handler:^(UIAlertAction *action) { PresentPhotoLibrary(self, YES); }]];
	[alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
	//---------------------------------------------------------------------------------------------------------------------------------------------
	[self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UIImagePickerControllerDelegate

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	UIImage *image = info[UIImagePickerControllerEditedImage];
	//---------------------------------------------------------------------------------------------------------------------------------------------
	UIImage *imagePicture = [Image square:image size:100];
	NSData *dataPicture = UIImageJPEGRepresentation(imagePicture, 0.6);
	//---------------------------------------------------------------------------------------------------------------------------------------------
	MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
	hud.mode = MBProgressHUDModeDeterminateHorizontalBar;
	//---------------------------------------------------------------------------------------------------------------------------------------------
	FIRStorage *storage = [FIRStorage storage];
	FIRStorageReference *reference = [[storage referenceForURL:FIREBASE_STORAGE] child:Filename(@"group", @"jpg")];
	FIRStorageUploadTask *task = [reference putData:dataPicture metadata:nil completion:^(FIRStorageMetadata *metadata, NSError *error)
	{
		[hud hideAnimated:YES];
		if (error == nil)
		{
			imageGroup.image = imagePicture;
			linkPicture = metadata.downloadURL.absoluteString;
		}
		else [ProgressHUD showError:@"Network error."];
	}];
	//---------------------------------------------------------------------------------------------------------------------------------------------
	[task observeStatus:FIRStorageTaskStatusProgress handler:^(FIRStorageTaskSnapshot *snapshot)
	{
		hud.progress = (float) snapshot.progress.completedUnitCount / (float) snapshot.progress.totalUnitCount;
	}];
	//---------------------------------------------------------------------------------------------------------------------------------------------
	[picker dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UIScrollViewDelegate

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	[self dismissKeyboard];
}

#pragma mark - Table view data source

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	return [sections count];
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	return [sections[section] count];
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	if ([sections[section] count] != 0)
	{
		return [[[UILocalizedIndexedCollation currentCollation] sectionTitles] objectAtIndex:section];
	}
	else return nil;
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	return [[UILocalizedIndexedCollation currentCollation] sectionIndexTitles];
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	return [[UILocalizedIndexedCollation currentCollation] sectionForSectionIndexTitleAtIndex:index];
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
	if (cell == nil) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"];
	//---------------------------------------------------------------------------------------------------------------------------------------------
	NSArray *dbusers_section = sections[indexPath.section];
	DBUser *dbuser = dbusers_section[indexPath.row];
	//---------------------------------------------------------------------------------------------------------------------------------------------
	cell.textLabel.text = dbuser.fullname;
	cell.accessoryType = [selection containsObject:dbuser.objectId] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
	//---------------------------------------------------------------------------------------------------------------------------------------------
	return cell;
}

#pragma mark - Table view delegate

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	//---------------------------------------------------------------------------------------------------------------------------------------------
	NSArray *dbusers_section = sections[indexPath.section];
	DBUser *dbuser = dbusers_section[indexPath.row];
	//---------------------------------------------------------------------------------------------------------------------------------------------
	if ([selection containsObject:dbuser.objectId])
		[selection removeObject:dbuser.objectId];
	else [selection addObject:dbuser.objectId];
	//---------------------------------------------------------------------------------------------------------------------------------------------
	UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
	cell.accessoryType = [selection containsObject:dbuser.objectId] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
}

#pragma mark - UISearchBarDelegate

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	[self loadUsers];
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar_
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	[searchBar setShowsCancelButton:YES animated:YES];
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar_
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	[searchBar setShowsCancelButton:NO animated:YES];
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar_
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	searchBar.text = @"";
	[searchBar resignFirstResponder];
	[self loadUsers];
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar_
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	[searchBar resignFirstResponder];
}

@end
